/* Copyright Airship and Contributors */

import Foundation
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationRemoteDataSchedulerProtocol: Sendable {
    func subscribe()
    func unsubscribe()
}

final class AutomationRemoteDataScheduler: AutomationRemoteDataSchedulerProtocol {
    private let remoteDataAccess: AutomationRemoteDataAccessProtocol
    private let engine: AutomationEngineProtocol
    private let frequencyLimitManager: FrequencyLimitManagerProtocol

    init(
        remoteDataAccess: AutomationRemoteDataAccessProtocol,
        engine: AutomationEngineProtocol,
        frequencyLimitManager: FrequencyLimitManagerProtocol
    ) {
        self.remoteDataAccess = remoteDataAccess
        self.engine = engine
        self.frequencyLimitManager = frequencyLimitManager
    }

    func subscribe() {
        // TODO: subscribe if not already subscribed
        // TODO: actually schedule IAA messages and constraints
    }

    func unsubscribe() {
        // TODO: cancel subscription
    }
}
