/* Copyright Airship and Contributors */

import Foundation

/// In-app automation remote data status.
public enum InAppAutomationUpdateStatus: Sendable {
    /// Remote data is current.
    case upToDate
    /// Remote data may be outdated; refresh in progress or deferred.
    case stale
    /// Remote data is known to be out of date.
    case outOfDate
}

