/* Copyright Airship and Contributors */

import Foundation

#if canImport(UIKit)
import UIKit
#endif

protocol WorkBackgroundTasksProtocol: Sendable {
    @MainActor
    func beginTask(
        _ name: String,
        expirationHandler: (@Sendable () -> Void)?
    ) throws -> any AirshipCancellable
}

final class WorkBackgroundTasks: WorkBackgroundTasksProtocol, Sendable {

    #if !os(watchOS)
    private let requestMap: AirshipMainActorValue<[UInt: UIBackgroundTaskIdentifier]> = AirshipMainActorValue([:])
    private let nextRequestID: AirshipMainActorValue<UInt> = AirshipMainActorValue(0)
    #endif

    @MainActor
    func beginTask(
        _ name: String,
        expirationHandler: (@Sendable () -> Void)? = nil
    ) throws -> any AirshipCancellable {
#if os(watchOS)
        let cancellable: CancellableValueHolder<UInt> = CancellableValueHolder(value: 0) { _ in
        }
        return cancellable
#else

        AirshipLogger.trace("Requesting task: \(name)")

        let requestID = nextRequestID.value
        nextRequestID.update { $0 += 1}

        let cancellable: CancellableValueHolder<UInt> = CancellableValueHolder(value: requestID) { requestID in
            Task { @MainActor in
                self.cancel(requestID: requestID)
            }
        }

        let application = UIApplication.shared

        let bgTask = application.beginBackgroundTask(withName: name) {
            AirshipLogger.trace("Task expired: \(name)")
            self.cancel(requestID: requestID)
            expirationHandler?()
        }

        self.requestMap.update { $0[requestID] = bgTask }

        guard let task = self.requestMap.value[requestID], task != UIBackgroundTaskIdentifier.invalid else {
            throw AirshipErrors.error("Unable to request background time.")
        }

        AirshipLogger.trace("Task granted: \(name)")
        return cancellable
        #endif
    }

    @MainActor
    private func cancel(requestID: UInt) {
#if !os(watchOS)
        let taskID = self.requestMap.value[requestID]
        self.requestMap.update { $0.removeValue(forKey: requestID) }

        guard let taskID = taskID, taskID != UIBackgroundTaskIdentifier.invalid else {
            return
        }

        UIApplication.shared.endBackgroundTask(taskID)
#endif
    }
}
