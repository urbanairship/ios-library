/* Copyright Airship and Contributors */

import Foundation

@testable
import AirshipCore

class TestBackgroundTasks: BackgroundTasksProtocol {
    var taskHandler: ((String, (@escaping () -> Void)) -> Disposable?)?

    func beginTask(_ name: String, expirationHandler: @escaping () -> Void) throws -> Disposable {
        let disposable = taskHandler?(name, expirationHandler)
        guard let disposable = disposable else {
            throw AirshipErrors.error("Unable to create task")
        }
        return disposable
    }


}

