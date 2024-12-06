/* Copyright Airship and Contributors */

/// Utility class that holds a value in a thread safe way. Once cancelled, setting a value
/// on the holder will cause it to immediately be cancelled with the block and the value to be
/// cleared.
/// - Note: for internal use only.  :nodoc:
public final class CancellableValueHolder<T: Sendable>: AirshipCancellable, @unchecked Sendable {
    private let lock: AirshipLock = AirshipLock()
    private let onCancel: (T) -> Void
    private var isCancelled: Bool = false
    private var _value: T?
    
    public var value: T? {
        get {
            var value: T? = nil
            lock.sync {
                value = _value
            }
            return value
        }
        set {
            lock.sync {
                if isCancelled {
                    if let value = newValue {
                        onCancel(value)
                    }
                } else {
                    _value = newValue
                }
            }
        }
    }
    
    
    public init(value: T, onCancel: @escaping @Sendable (T) -> Void) {
        self._value = value
        self.onCancel = onCancel
    }
    
    public init(onCancel: @escaping @Sendable (T) -> Void) {
        self.onCancel = onCancel
    }
    
    public func cancel() {
        lock.sync {
            guard isCancelled == false else { return }
            isCancelled = true
            if let value = value {
                onCancel(value)
                _value = nil
            }
        }
    }
    
    public static func cancellableHolder() -> CancellableValueHolder<any AirshipCancellable> {
        return CancellableValueHolder<any AirshipCancellable>() { cancellable in
            cancellable.cancel()
        }
    }
}


