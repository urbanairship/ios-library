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
public final class AirshipMainActorCancellableBlock: AirshipMainActorCancellable, @unchecked Sendable {
    private var block: (@Sendable @MainActor () -> Void)?

    public init(block: @escaping @MainActor @Sendable () -> Void) {
        self.block = block
    }

    @MainActor
    public func cancel() {
        self.block?()
        self.block = nil
    }
}
