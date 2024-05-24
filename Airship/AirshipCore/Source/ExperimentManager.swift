/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
final class ExperimentManager: ExperimentDataProvider {
    private static let payloadType = "experiments"
    
    private let dataStore: PreferenceDataStore
    private let remoteData: RemoteDataProtocol
    private let audienceChecker: DeviceAudienceChecker
    private let date: AirshipDateProtocol

    init(
        dataStore: PreferenceDataStore,
        remoteData: RemoteDataProtocol,
        audienceChecker: DeviceAudienceChecker = DefaultDeviceAudienceChecker(),
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.dataStore = dataStore
        self.remoteData = remoteData
        self.audienceChecker = audienceChecker
        self.date = date
    }
    
    public func evaluateExperiments(
        info: MessageInfo,
        deviceInfoProvider: AudienceDeviceInfoProvider
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
                audience: experiment.audienceSelector,
                newUserEvaluationDate: experiment.created,
                deviceInfoProvider: deviceInfoProvider
            )

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
            let messageType = criteria.messageTypePredicate?.evaluate(info.messageType) ?? false
            let campaigns = criteria.campaignsPredicate?.evaluate(info.campaigns?.unWrap()) ?? false
            return messageType || campaigns
        } ?? false
    }

    func isActive(date: Date) -> Bool {
        return self.timeCriteria?.isActive(date: date) ?? true
    }
}


