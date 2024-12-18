/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct AirshipStateOverrides: Encodable, Equatable, Sendable {
    let appVersion: String
    let sdkVersion: String
    let notificationOptIn: Bool
    let localeLangauge: String?
    let localeCountry: String?

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version"
        case sdkVersion = "sdk_version"
        case notificationOptIn = "notification_opt_in"
        case localeLangauge = "locale_language"
        case localeCountry = "locale_country"
    }
}
