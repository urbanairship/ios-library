/* Copyright Airship and Contributors */

import Foundation
import UIKit

protocol BackgroundTasksProtocol {
#if !os(watchOS)
    func beginTask(_ name: String, expirationHandler: @escaping () -> Void) throws -> Disposable
    var timeRemaining: TimeInterval { get }
#endif
}

class BackgroundTasks: BackgroundTasksProtocol {
    
#if !os(watchOS)
    
    var timeRemaining: TimeInterval {
        UIApplication.shared.backgroundTimeRemaining
    }

    func beginTask(_ name: String, expirationHandler: @escaping () -> Void) throws -> Disposable {
        let application = UIApplication.shared
        var taskID = UIBackgroundTaskIdentifier.invalid

        let disposable = Disposable {
            if (taskID != UIBackgroundTaskIdentifier.invalid) {
                application.endBackgroundTask(taskID)
                taskID = UIBackgroundTaskIdentifier.invalid
            }
        }

        taskID = application.beginBackgroundTask(withName: name) {
            expirationHandler()
        }

        if (taskID == UIBackgroundTaskIdentifier.invalid) {
            throw AirshipErrors.error("Unable to request background time.")
        }

        return disposable
    }
    
#endif
    
}
