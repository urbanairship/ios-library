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
    func onStateChanged(
        _ state: AirshipJSON
    )
}

public extension ThomasDelegate {
    @MainActor
    func onStateChanged(_ state: AirshipJSON) {
        // no-op
    }
}
