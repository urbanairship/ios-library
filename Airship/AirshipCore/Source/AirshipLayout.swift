/* Copyright Airship and Contributors */

import SwiftUI

/// AirshipLayout
public struct AirshipLayout: ThomasSerializable {
    /// The view DSL
    let view: ThomasViewInfo

    /// Layout DSL version
    let version: Int

    /// Presentation configuration
    let presentation: ThomasPresentationInfo

    public var isEmbedded: Bool {
        guard case .embedded(_) = presentation else {
            return false
        }

        return true
    }
}


extension AirshipLayout {
    static let minLayoutVersion = 1
    static let maxLayoutVersion = 2

    public func validate() -> Bool
    {
        guard
            self.version >= Self.minLayoutVersion
                && self.version <= Self.maxLayoutVersion else {
            return false
        }

        return true
    }
}

