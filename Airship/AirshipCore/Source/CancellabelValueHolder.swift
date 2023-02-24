/* Copyright Airship and Contributors */

/// Utility class that holds a value in a thread safe way. Once cancelled, setting a value
/// on the holder will cause it to immediately be cancelled witht he block and the value to be
/// cleared.
/// - Note: for internal use only.  :nodoc:
class CancellabelValueHolder<T: Sendable>: AirshipCancellable, @unchecked Sendable {
    private let lock: AirshipLock = AirshipLock()
    private let onCancel: (T) -> Void
    private var isCancelled: Bool = false
    private var _value: T?
    
    var value: T? {
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
    
    
    init(value: T, onCancel: @escaping @Sendable (T) -> Void) {
        self._value = value
        self.onCancel = onCancel
    }
    
    init(onCancel: @escaping @Sendable (T) -> Void) {
        self.onCancel = onCancel
    }
    
    func cancel() {
        lock.sync {
            guard isCancelled == false else { return }
            isCancelled = true
            if let value = value {
                onCancel(value)
                _value = nil
            }
        }
    }
    
    static func cancellableHolder() -> CancellabelValueHolder<AirshipCancellable> {
        return CancellabelValueHolder<AirshipCancellable>() { cancellable in
            cancellable.cancel()
        }
    }
}


