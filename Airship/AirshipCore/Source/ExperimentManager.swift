/* Copyright Airship and Contributors */



/// NOTE: For internal use only. :nodoc:
final class ExperimentManager: ExperimentDataProvider {
    private static let payloadType = "experiments"
    
    private let dataStore: PreferenceDataStore
    private let remoteData: any RemoteDataProtocol
    private let audienceChecker: any DeviceAudienceChecker
    private let date: any AirshipDateProtocol

    init(
        dataStore: PreferenceDataStore,
        remoteData: any RemoteDataProtocol,
        audienceChecker: any DeviceAudienceChecker,
        date: any AirshipDateProtocol = AirshipDate.shared
    ) {
        self.dataStore = dataStore
        self.remoteData = remoteData
        self.audienceChecker = audienceChecker
        self.date = date
    }
    
    public func evaluateExperiments(
        info: MessageInfo,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> ExperimentResult? {
        let experiments = await getExperiments(info: info)
        guard !experiments.isEmpty else {
            return nil
        }

        
        let contactID = await deviceInfoProvider.stableContactInfo.contactID
        let channelID = try await deviceInfoProvider.channelID

        var evaluatedMetadata: [AirshipJSON] = []
        var isMatch: Bool = false

        for experiment in experiments {
            isMatch = try await self.audienceChecker.evaluate(
                audienceSelector: .combine(
                    compoundSelector: experiment.compoundAudience?.selector,
                    deviceSelector: experiment.audienceSelector
                ),
                newUserEvaluationDate: experiment.created,
                deviceInfoProvider: deviceInfoProvider
            ).isMatch

            evaluatedMetadata.append(experiment.reportingMetadata)

            if (isMatch) {
                break
            }
        }
        
        return ExperimentResult(
            channelID: channelID,
            contactID: contactID,
            isMatch: isMatch,
            reportingMetadata: evaluatedMetadata
        )
    }

    func getExperiments(info: MessageInfo) async -> [Experiment] {
        return await remoteData
            .payloads(types: [Self.payloadType])
            .compactMap { payload in
                payload.data.object?[Self.payloadType]?.array
            }
            .flatMap { $0 }
            .compactMap { json in
                do {
                    let experiment: Experiment = try json.decode(decoder: Experiment.decoder)
                    return experiment
                } catch {
                    AirshipLogger.error("Failed to parse experiment \(error)")
                    return nil
                }
            }
            .filter { $0.isActive(date: self.date.now) }
            .filter { !$0.isExcluded(info: info) }
    }
    
}

private extension Experiment {
    func isExcluded(info: MessageInfo) -> Bool {
        return self.exclusions?.contains { criteria in
            let messageType = criteria.messageTypePredicate?.evaluate(json: .string(info.messageType)) ?? false
            let campaigns = criteria.campaignsPredicate?.evaluate(json: info.campaigns ?? .null) ?? false
            return messageType || campaigns
        } ?? false
    }
    func isActive(date: Date) -> Bool {
        return self.timeCriteria?.isActive(date: date) ?? true
    }
}


