/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
final class ExperimentManager: ExperimentDataProvider {
    private static let payloadType = "experiments"
    
    private let dataStore: PreferenceDataStore
    private let remoteData: RemoteDataProtocol
    private let channelIDProvider: () -> String?
    private let stableContactIDProvider: () async -> String
    private let audienceChecker: DeviceAudienceChecker
    private let date: AirshipDateProtocol

    init(
        dataStore: PreferenceDataStore,
        remoteData: RemoteDataProtocol,
        channelIDProvider: @escaping () -> String?,
        stableContactIDProvider: @escaping () async -> String,
        audienceChecker: DeviceAudienceChecker = DefaultDeviceAudienceChecker(),
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.dataStore = dataStore
        self.remoteData = remoteData
        self.channelIDProvider = channelIDProvider
        self.stableContactIDProvider = stableContactIDProvider
        self.audienceChecker = audienceChecker
        self.date = date
    }
    
    public func evaluateExperiments(info: MessageInfo, contactID: String?) async throws -> ExperimentResult {
        let contactID = await resolveContactID(contactID: contactID)
        guard let channelID = channelIDProvider() else {
            // Since we pull this after a stable contact ID this should never happen. Ideally we have
            // a way to wait for it like we do the contact ID.
            throw AirshipErrors.error("Channel ID missing, unable to evaluate hold out groups.")
        }

        var evaluatedMetadata: [AirshipJSON] = []
        var isMatch: Bool = false

        let experiments = await getExperiments()
        for experiment in experiments {
            if (!experiment.isActive(date: self.date.now)) {
                continue
            }

            if (experiment.isExcluded(info: info)) {
                continue
            }

            isMatch = try await self.audienceChecker.evaluate(
                audience: experiment.audienceSelector,
                newUserEvaluationDate: experiment.created,
                contactID: contactID
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
            evaluatedExperimentsReportingData: evaluatedMetadata
        )
    }

    private func resolveContactID(contactID: String?) async -> String {
        if let contactID = contactID {
            return contactID
        }
        return await stableContactIDProvider()
    }
    
    func getExperiment(id: String) async -> Experiment? {
        return await getExperiments().first(where: { $0.id == id })
    }
    
    func getExperiments() async -> [Experiment] {
        return await remoteData
            .payloads(types: [Self.payloadType])
            .map { $0.data }
            .compactMap { $0[Self.payloadType] as? [[String: Any]] }
            .flatMap { $0 }
            .compactMap(Experiment.from)
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
        let currentMS = date.millisecondsSince1970

        if let startMS = timeCriteria?.start, currentMS < startMS {
            return false
        }

        if let endMS = timeCriteria?.end, currentMS >= endMS {
            return false
        }

        return true
    }
}

