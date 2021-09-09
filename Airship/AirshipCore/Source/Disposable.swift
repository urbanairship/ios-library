/* Copyright Airship and Contributors */

/**
 * A convenience class for creating self-referencing cancellation tokens.
 *
 * @note It is left up to the creator to determine what is disposed of and
 * under what circumstances.  This includes threading and memory management concerns.
 */
@objc(UADisposable)
public class Disposable : NSObject {
    private var disposalBlock: (() -> Void)?
    private let lock = NSRecursiveLock()

    /**
     * Create a new disposable.
     *
     * @param disposalBlock A block to be executed on dispose.
     */
    @objc
    public init(_ disposalBlock: @escaping () -> Void ) {
        self.disposalBlock = disposalBlock
        super.init()
    }


    /**
     * Create a new disposable.
     */
    @objc
    public override init() {
        super.init()
    }

    /**
     * Dispose of associated resources.
     */
    @objc
    public func dispose() {
        self.lock.lock()
        self.disposalBlock?()
        self.disposalBlock = nil
        self.lock.unlock()
    }
}
