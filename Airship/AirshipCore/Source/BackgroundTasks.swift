/* Copyright Airship and Contributors */

import Foundation
import UIKit

protocol BackgroundTasksProtocol {
#if !os(watchOS)
    func beginTask(_ name: String, expirationHandler: @escaping () -> Void) throws -> Disposable
#endif
}

class BackgroundTasks: BackgroundTasksProtocol {
    
#if !os(watchOS)

    func beginTask(_ name: String, expirationHandler: @escaping () -> Void) throws -> Disposable {
        let application = UIApplication.shared
        var taskID = UIBackgroundTaskIdentifier.invalid

        let disposable = Disposable {
            if (taskID != UIBackgroundTaskIdentifier.invalid) {
                AirshipLogger.trace("Ending background task: \(name)")
                application.endBackgroundTask(taskID)
                taskID = UIBackgroundTaskIdentifier.invalid
            }
        }

        taskID = application.beginBackgroundTask(withName: name) {
            expirationHandler()
            disposable.dispose()
        }

        if (taskID == UIBackgroundTaskIdentifier.invalid) {
            throw AirshipErrors.error("Unable to request background time.")
        }

        AirshipLogger.trace("Background task started: \(name)")

        return disposable
    }
    
#endif
    
}
