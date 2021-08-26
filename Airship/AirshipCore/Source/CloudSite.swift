/* Copyright Airship and Contributors */

import Foundation

/// Represents the possible sites.
@objc(UACloudSite)
public enum CloudSite : Int {
    /// Represents the US cloud site. This is the default value.
    /// Projects avialable at go.airship.com must use this value.
    @objc(UACloudSiteUS)
    case us = 0
    /// Represents the EU cloud site.
    /// Projects avialable at go.airship.eu must use this value.
    @objc(UACloudSiteEU)
    case eu = 1
}
