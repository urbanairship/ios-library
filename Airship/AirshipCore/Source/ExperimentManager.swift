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

    init(
        dataStore: PreferenceDataStore,
        remoteData: RemoteDataProtocol,
        channelIDProvider: @escaping () -> String?,
        stableContactIDProvider: @escaping () async -> String,
        audienceChecker: DeviceAudienceChecker = DefaultDeviceAudienceChecker()
    ) {
        self.dataStore = dataStore
        self.remoteData = remoteData
        self.channelIDProvider = channelIDProvider
        self.stableContactIDProvider = stableContactIDProvider
        self.audienceChecker = audienceChecker
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

        for experiment in await getExperiments() {
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
    
    private func getExperiments() async -> [Experiment] {
        return await remoteData
            .payloads(types: [Self.payloadType])
            .map { $0.data }
            .compactMap { $0[Self.payloadType] as? [[String: Any]] }
            .flatMap { $0 }
            .compactMap(Experiment.from)
    }
}

private extension MessageCriteria {
    func isExcluded(_ info: MessageInfo) -> Bool {
        return messageTypePredicate?.evaluate(info.messageType) ?? false
    }
}
