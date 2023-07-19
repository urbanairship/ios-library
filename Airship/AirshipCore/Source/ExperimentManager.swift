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
    
    public func evaluateExperiments(info: MessageInfo, contactID: String?) async throws -> ExperimentResult? {
        let experiments = await getExperiments(info: info)
        guard !experiments.isEmpty else {
            return nil
        }

        let contactID = await resolveContactID(contactID: contactID)
        guard let channelID = channelIDProvider() else {
            // Since we pull this after a stable contact ID this should never happen. Ideally we have
            // a way to wait for it like we do the contact ID.
            throw AirshipErrors.error("Channel ID missing, unable to evaluate hold out groups.")
        }

        var evaluatedMetadata: [AirshipJSON] = []
        var isMatch: Bool = false

        for experiment in experiments {
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
    
    func getExperiments(info: MessageInfo) async -> [Experiment] {
        return await remoteData
            .payloads(types: [Self.payloadType])
            .map { $0.data }
            .compactMap { $0[Self.payloadType] as? [[String: Any]] }
            .flatMap { $0 }
            .compactMap(Experiment.from)
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

