/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public extension Color {
    static var airshipTappableClear: Color { Color.white.opacity(0.001) }
    static var airshipShadowColor: Color { Color.black.opacity(0.33) }
}
