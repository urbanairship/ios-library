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

    private let requestMap: AirshipMainActorWrapper<[UInt: UIBackgroundTaskIdentifier]> = AirshipMainActorWrapper([:])
    private let nextRequestID: AirshipMainActorWrapper<UInt> = AirshipMainActorWrapper(0)

    @MainActor
    func beginTask(
        _ name: String,
        expirationHandler: (@Sendable () -> Void)? = nil
    ) throws -> AirshipCancellable {
        AirshipLogger.trace("Requesting task: \(name)")

        let requestID = nextRequestID.value
        nextRequestID.value += 1

        let cancellable: CancellabelValueHolder<UInt> = CancellabelValueHolder(value: requestID) { requestID in
            Task { @MainActor in
                self.cancel(requestID: requestID)
            }
        }

        #if os(watchOS)
        return cancellable
        #else


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
