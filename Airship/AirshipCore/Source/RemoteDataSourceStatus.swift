/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum RemoteDataSourceStatus: Sendable {
    case upToDate
    case stale
    case outOfDate
}
