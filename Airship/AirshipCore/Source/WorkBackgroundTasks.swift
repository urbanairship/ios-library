/* Copyright Airship and Contributors */

import Foundation
import UIKit

protocol WorkBackgroundTasksProtocol {
    func beginTask(
        _ name: String,
        expirationHandler: (() -> Void)?
    ) throws -> Disposable
}

class WorkBackgroundTasks: WorkBackgroundTasksProtocol {

    func beginTask(
        _ name: String,
        expirationHandler: (() -> Void)? = nil
    )
        throws -> Disposable
    {
        #if os(watchOS)
        return Disposable()
        #else
        let application = UIApplication.shared
        var taskID = UIBackgroundTaskIdentifier.invalid

        let disposable = Disposable {
            if taskID != UIBackgroundTaskIdentifier.invalid {
                application.endBackgroundTask(taskID)
                taskID = UIBackgroundTaskIdentifier.invalid
            }
        }

        taskID = application.beginBackgroundTask(withName: name) {
            expirationHandler?()
            disposable.dispose()
        }

        if taskID == UIBackgroundTaskIdentifier.invalid {
            throw AirshipErrors.error("Unable to request background time.")
        }

        return disposable
        #endif
    }
}
