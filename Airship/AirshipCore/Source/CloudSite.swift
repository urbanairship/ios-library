/* Copyright Airship and Contributors */

import Foundation

@objc
/// Represents the possible sites.
public enum CloudSite: Int, Sendable {
    /// Represents the US cloud site. This is the default value.
    /// Projects available at go.airship.com must use this value.
    case us = 0
    /// Represents the EU cloud site.
    /// Projects available at go.airship.eu must use this value.
    case eu = 1
}
