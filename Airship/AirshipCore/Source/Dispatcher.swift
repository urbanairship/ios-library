/* Copyright Airship and Contributors */

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UADispatcherTimeBase)
public enum DispatcherTimeBase : Int {
    /// Wall time.
    case wall

    /// System time.
    case system
}

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UADispatcher)
open class UADispatcher : NSObject {
    @objc
    public static let main: UADispatcher = UADispatcher(queue: DispatchQueue.main)

    @objc
    public static let global: UADispatcher = UADispatcher.globalDispatcher(.background)

    private static let dispatchKey = DispatchSpecificKey<UADispatcher>()
    private static var globalDispatchers: [DispatchQoS.QoSClass : UADispatcher] =  [:]
    private static let lock = NSRecursiveLock()

    private let queue: DispatchQueue

    public init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
        queue.setSpecific(key: UADispatcher.dispatchKey, value: self)
    }

    class func globalDispatcher(_ qos: DispatchQoS.QoSClass) -> UADispatcher {
        if let dispatcher = globalDispatchers[qos] {
            return dispatcher
        }

        self.lock.lock()
        let dispatcher = UADispatcher(queue: DispatchQueue.global(qos: qos))
        globalDispatchers[qos] = dispatcher
        self.lock.unlock()

        return dispatcher
    }
    
    public class func serial(_ qos: DispatchQoS) -> UADispatcher {
        let queue = DispatchQueue(label: "com.urbanairship.dispatcher.serial_queue", qos: qos)
        return UADispatcher(queue: queue)
    }

    @objc
    public class func serial() -> UADispatcher {
        return self.serial(.default)
    }

    @objc
    public class func serialUtility() -> UADispatcher {
        return self.serial(.utility)
    }

    @objc
    open func dispatchSync(_ block: @escaping () -> Void) {
        queue.sync(execute: block)
    }

    @objc
    open func doSync(_ block: @escaping () -> Void) {
        if isCurrentQueue() {
            block()
        } else {
            dispatchSync(block)
        }
    }

    @objc
    open func dispatchAsyncIfNecessary(_ block: @escaping () -> Void) {
        if isCurrentQueue() {
            block()
        } else {
            dispatchAsync(block)
        }
    }

    @objc
    open func dispatchAsync(_ block: @escaping () -> Void) {
        queue.async(execute: block)
    }

    @objc
    @discardableResult
    open func dispatch(after delay: TimeInterval, timebase: DispatcherTimeBase, block: @escaping () -> Void) -> Disposable {
        let workItem = DispatchWorkItem(block: block)

        if (delay == 0) {
            queue.async(execute: workItem)
        } else {
            if timebase == .wall {
                queue.asyncAfter(wallDeadline: DispatchWallTime.now() + delay, execute: workItem)
            } else {
                queue.asyncAfter(deadline: DispatchTime.now() + delay, execute: workItem)
            }
        }

        return Disposable {
            if (!workItem.isCancelled) {
                workItem.cancel()
            }
        }
    }

    @objc
    @discardableResult
    open func dispatch(after delay:TimeInterval, block: @escaping () -> Void) -> Disposable {
        return dispatch(after: delay, timebase: .wall, block: block)
    }

    private func isCurrentQueue() -> Bool {
        if (DispatchQueue.getSpecific(key: UADispatcher.dispatchKey) == self) {
            return true
        } else if self === UADispatcher.main && Thread.isMainThread {
            return true
        } else {
            return false
        }
    }
}
