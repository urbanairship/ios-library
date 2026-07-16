/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol AirshipCancellable: Sendable {
    func cancel()
}

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol AirshipMainActorCancellable: Sendable {
    @MainActor
    func cancel()
}

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class AirshipMainActorCancellableBlock: AirshipMainActorCancellable, Sendable {
    private let block: AirshipAtomicValue<(@Sendable @MainActor () -> Void)?> = AirshipAtomicValue<(@Sendable @MainActor () -> Void)?>(nil)

    public init(block: @escaping @MainActor @Sendable () -> Void) {
        self.block.set(block)
    }

    @MainActor
    public func cancel() {
        self.block.value?()
        self.block.set(nil)
    }
}
