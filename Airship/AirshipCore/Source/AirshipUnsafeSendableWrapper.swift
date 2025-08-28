/* Copyright Airship and Contributors */



/// - Note: for internal use only.  :nodoc:
public final class AirshipUnsafeSendableWrapper<T>: @unchecked Sendable {
    public var value: T
    public init(_ value: T) {
        self.value = value
    }
}
