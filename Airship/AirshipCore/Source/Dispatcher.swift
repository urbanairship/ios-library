/* Copyright Airship and Contributors */

protocol UADispatcher: AnyObject, Sendable {
    func doSync(_ block: @Sendable @escaping () -> Void)
    func dispatchAsyncIfNecessary(_ block:  @Sendable @escaping () -> Void)
    func dispatchAsync(_ block:  @Sendable  @escaping () -> Void)
}

final class DefaultDispatcher: UADispatcher, Sendable {
    static let main: DefaultDispatcher = DefaultDispatcher(
        queue: DispatchQueue.main
    )

    private static let dispatchKey = DispatchSpecificKey<DefaultDispatcher>()

    private let queue: DispatchQueue

    private init(queue: DispatchQueue) {
        self.queue = queue
        queue.setSpecific(key: DefaultDispatcher.dispatchKey, value: self)
    }

    class func serial(_ qos: DispatchQoS = .default) -> DefaultDispatcher {
        let queue = DispatchQueue(
            label: "com.urbanairship.dispatcher.serial_queue",
            qos: qos
        )
        return DefaultDispatcher(queue: queue)
    }

    func doSync(_ block: @escaping () -> Void) {
        if isCurrentQueue() {
            block()
        } else {
            queue.sync(execute: block)
        }
    }

    func dispatchAsyncIfNecessary(_ block: @escaping () -> Void) {
        if isCurrentQueue() {
            block()
        } else {
            dispatchAsync(block)
        }
    }

    func dispatchAsync(_ block: @escaping () -> Void) {
        queue.async(execute: block)
    }

    private func isCurrentQueue() -> Bool {
        if DispatchQueue.getSpecific(key: DefaultDispatcher.dispatchKey) === self {
            return true
        } else if self === DefaultDispatcher.main && Thread.isMainThread {
            return true
        } else {
            return false
        }
    }
}
