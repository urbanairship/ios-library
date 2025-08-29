/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public enum RemoteDataSourceStatus: Sendable {
    case upToDate
    case stale
    case outOfDate
}
