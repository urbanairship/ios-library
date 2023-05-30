/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAExperimentManager)
public final class ExperimentManager: NSObject, Component, ExperimentDataProvider {
    
    private static let payloadType = "experiments"
    
    private let dataStore: PreferenceDataStore
    private let remoteData: RemoteDataProtocol
    private let getChannelId: () -> String?
    private let getStableContactId: () async -> String
    
    private let disableHelper: ComponentDisableHelper

    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get { return disableHelper.enabled }
        set { disableHelper.enabled = newValue }
    }
    
    init(
        dataStore: PreferenceDataStore,
        remoteData: RemoteDataProtocol,
        channelIdFetcher: @escaping () -> String?,
        stableContactIdFetcher: @escaping () async -> String
    ) {
        self.dataStore = dataStore
        self.remoteData = remoteData
        self.getChannelId = channelIdFetcher
        self.getStableContactId = stableContactIdFetcher
        
        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "UAExperimentaManager"
        )
        
        super.init()
    }
    
    public func evaluateGlobalHoldouts(info: MessageInfo, contactId: String?) async -> ExperimentResult? {
        guard let channelId = getChannelId() else { return nil }
        
        let evaluationContactId: String
        if let id = contactId {
            evaluationContactId = id
        } else {
            evaluationContactId = await getStableContactId()
        }
        
        let properties = generateExperimentProperties(channelId: channelId, contactId: evaluationContactId)
        let experiments = await getExperiments()
        
        var result: ExperimentResult? = nil
        
        for experiment in experiments {
            let tryResolve = getResolutionFunction(for: experiment)
            let resolved = tryResolve(experiment, info, properties)
            
            if resolved {
                result = ExperimentResult(
                    channelId: channelId,
                    contactId: evaluationContactId,
                    experimentId: experiment.id,
                    reportingMetadata: experiment.reportingMetadata)
                break
            }
        }
        
        return result
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

// MARK: - Experiments Evaluation
private extension ExperimentManager {
    private func generateExperimentProperties(channelId: String, contactId: String) -> [String: String] {
        return [
            AudienceHash.Identifier.channel.rawValue: channelId,
            AudienceHash.Identifier.contact.rawValue: contactId
        ]
    }
    
    private func getResolutionFunction(for experiment: Experiment) -> ResolutionFunction {
        switch (experiment.resolutionType) {
        case .static:
            return self.resolveStatic
        }
    }
    
    private func resolveStatic(experiment: Experiment, info: MessageInfo, properties: [String: String]) -> Bool {
        if experiment.exclusions.contains(where: { $0.isExcluded(info) }) {
            return false
        }
        
        return experiment.audienceSelector.isMatching(properties: properties)
    }
}

private extension MessageCriteria {
    func isExcluded(_ info: MessageInfo) -> Bool {
        return messageTypePredicate?.evaluate(info.messageType) ?? false
    }
}

private extension AudienceSelector {
    func isMatching(properties: [String: String]) -> Bool {
        return hash
            .calculateHash(for: properties)
            .map(bucket.contains)
        ?? false
    }
}

private extension AudienceHash {
    func calculateHash(for properties: [String: String]) -> UInt64? {
        guard let key = properties[property.rawValue] else {
            AirshipLogger.error("can't find device property \(property.rawValue)")
            return nil
        }
        
        let value = overrides?[key] ?? key
        let hash = getHashFunction()("\(self.prefix)\(value)")
        
        return hash % numberOfBuckets
    }
    
    private func getHashFunction() -> HashFunction {
        switch (self.algorithm) {
        case .farm:
            return FarmHashFingerprint64.fingerprint
        }
    }
}

typealias ResolutionFunction = (Experiment, MessageInfo, [String: String]) -> Bool
typealias HashFunction = (String) -> UInt64
