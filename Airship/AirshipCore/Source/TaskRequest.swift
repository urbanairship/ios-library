/* Copyright Airship and Contributors */

/**
 * - Note: For internal use only. :nodoc:
 */
class UATaskRequest {
    let taskID: String
    let options: TaskRequestOptions
    let launcher: TaskLauncher

    init(taskID: String, options: TaskRequestOptions, launcher: TaskLauncher) {
        self.taskID = taskID
        self.options = options
        self.launcher = launcher
    }
}
