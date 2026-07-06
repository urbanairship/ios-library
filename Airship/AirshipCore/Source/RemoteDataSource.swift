/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public enum RemoteDataSource: Int, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case app
    case contact
}
