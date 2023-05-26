/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAExperimentaManager)
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
