/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public protocol AirshipCancellable: Sendable {
    func cancel()
}

/// - Note: for internal use only.  :nodoc:
public protocol AirshipMainActorCancellable: Sendable {
    @MainActor
    func cancel()
}

/// - Note: for internal use only.  :nodoc:
public final class AirshipMainActorCancellableBlock: AirshipMainActorCancellable, Sendable {
    private let block = AirshipAtomicValue<(@Sendable @MainActor () -> Void)?>(nil)

    public init(block: @escaping @MainActor @Sendable () -> Void) {
        self.block.value = block
    }

    @MainActor
    public func cancel() {
        self.block.value?()
        self.block.value = nil
    }
}
