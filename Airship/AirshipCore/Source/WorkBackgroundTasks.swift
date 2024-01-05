/* Copyright Airship and Contributors */

import Foundation
import UIKit

protocol WorkBackgroundTasksProtocol: Sendable {
    @MainActor
    func beginTask(
        _ name: String,
        expirationHandler: (@Sendable () -> Void)?
    ) throws -> AirshipCancellable
}

final class WorkBackgroundTasks: WorkBackgroundTasksProtocol, Sendable {

    #if !os(watchOS)
    private let requestMap: AirshipMainActorWrapper<[UInt: UIBackgroundTaskIdentifier]> = AirshipMainActorWrapper([:])
    private let nextRequestID: AirshipMainActorWrapper<UInt> = AirshipMainActorWrapper(0)
    #endif

    @MainActor
    func beginTask(
        _ name: String,
        expirationHandler: (@Sendable () -> Void)? = nil
    ) throws -> AirshipCancellable {
        #if os(watchOS)
        let cancellable: CancellableValueHolder<UInt> = CancellableValueHolder(value: 0) { _ in
        }
        return cancellable
        #else

        AirshipLogger.trace("Requesting task: \(name)")

        let requestID = nextRequestID.value
        nextRequestID.value += 1

        let cancellable: CancellableValueHolder<UInt> = CancellableValueHolder(value: requestID) { requestID in
            Task { @MainActor in
                self.cancel(requestID: requestID)
            }
        }

        let application = UIApplication.shared
        self.requestMap.value[requestID] = application.beginBackgroundTask(withName: name) {
            AirshipLogger.trace("Task expired: \(name)")
            self.cancel(requestID: requestID)
            expirationHandler?()
        }

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
        guard let taskID = self.requestMap.value.removeValue(forKey: requestID),
              taskID != UIBackgroundTaskIdentifier.invalid
        else {
            return
        }

        UIApplication.shared.endBackgroundTask(taskID)
#endif
    }
}
