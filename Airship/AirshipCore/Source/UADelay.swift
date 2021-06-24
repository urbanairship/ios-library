/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class UADelay : NSObject {
    private let seconds: TimeInterval
    private let semaphore: DispatchSemaphore

    @objc
    public init(_ seconds: TimeInterval) {
        self.seconds = seconds
        semaphore = DispatchSemaphore(value: 0)
    }

    @objc
    public func cancel() {
        semaphore.signal()
    }

    @objc
    public func start() {
        _ = semaphore.wait(timeout: DispatchTime.now() + seconds)
    }
}
