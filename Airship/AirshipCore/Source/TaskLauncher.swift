/* Copyright Airship and Contributors */

/**
 * - Note: For internal use only. :nodoc:
 */
class TaskLauncher {
    private var dispatcher: UADispatcher
    private var launchHandler: (Task) -> Void

    init(dispatcher: UADispatcher?, launchHandler: @escaping (Task) -> Void) {
        self.dispatcher = dispatcher ?? UADispatcher.global
        self.launchHandler = launchHandler
    }

    func launch(_ task: Task) {
        self.dispatcher.dispatchAsync { [weak self] in
            self?.launchHandler(task)
        }
    }
}
