/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
class UATaskLauncher {
    private var dispatcher: UADispatcher
    private var launchHandler: (UATask) -> Void

    init(dispatcher: UADispatcher?, launchHandler: @escaping (UATask) -> Void) {
        self.dispatcher = dispatcher ?? UADispatcher.global
        self.launchHandler = launchHandler
    }

    func launch(_ task: UATask) {
        self.dispatcher.dispatchAsync { [weak self] in
            self?.launchHandler(task)
        }
    }
}
