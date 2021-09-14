/* Copyright Airship and Contributors */

/// Delay protocol.
/// For internal use only. :nodoc:
@objc(UADelayProtocol)
public protocol DelayProtocol {
    @objc
    func cancel()

    @objc
    func start()
}

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UADelay)
public class Delay : NSObject, DelayProtocol {
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
