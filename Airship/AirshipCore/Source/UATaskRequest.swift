/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
class UATaskRequest {
    let taskID: String
    let options: UATaskRequestOptions
    let launcher: UATaskLauncher

    init(taskID: String, options: UATaskRequestOptions, launcher: UATaskLauncher) {
        self.taskID = taskID
        self.options = options
        self.launcher = launcher
    }
}
