/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public protocol ThomasDelegate: Sendable {

    @MainActor
    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool)

    @MainActor
    func onReportingEvent(_ event: ThomasReportingEvent)

    @MainActor
    func onDismissed(cancel: Bool)

    @MainActor
    func onStateChanged(_ state: AirshipJSON)
}

public extension ThomasDelegate {
    @MainActor
    func onStateChanged(_ state: AirshipJSON) {
        // no-op
    }
}

@MainActor
public final class ThomasDismissHandle {
    private var onDismissBlocks: [(Bool) -> Void] = []

    public init() {}

    /// Adds a block to be called when ``dismiss(cancel:)`` is invoked. All blocks are run; order is the order they were added.
    func addOnDismiss(_ block: @escaping (Bool) -> Void) {
        onDismissBlocks.append(block)
    }

    public func dismiss(cancel: Bool = false) {
        for block in onDismissBlocks {
            block(cancel)
        }
        onDismissBlocks.removeAll()
    }
}
