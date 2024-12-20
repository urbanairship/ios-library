/* Copyright Airship and Contributors */

import Foundation

/// A collection of properties defining an automation audience
public struct DeviceAudienceSelector: Sendable, Codable, Equatable {
    var newUser: Bool?
    var notificationOptIn: Bool?
    var locationOptIn: Bool?
    var languageIDs: [String]?
    var tagSelector: DeviceTagSelector?
    var requiresAnalytics: Bool?
    var permissionPredicate: JSONPredicate?
    var versionPredicate: JSONPredicate?
    var testDevices: [String]?
    var hashSelector: AudienceHashSelector?
    var deviceTypes: [String]?

    enum CodingKeys: String, CodingKey {
        case newUser = "new_user"
        case notificationOptIn = "notification_opt_in"
        case locationOptIn = "location_opt_in"
        case languageIDs = "locale"
        case tagSelector = "tags"
        case requiresAnalytics = "requires_analytics"
        case permissionPredicate = "permissions"
        case versionPredicate = "app_version"
        case testDevices = "test_devices"
        case hashSelector = "hash"
        case deviceTypes = "device_types"
    }


    /// Audience selector initializer
    /// - Parameters:
    ///   - newUser: Flag indicating if audience consists of new users
    ///   - notificationOptIn: Flag indicating if audience consists of users opted into notifications
    ///   - locationOptIn: Flag indicating if audience consists of users that have opted into location
    ///   - languageIDs: Array of language IDs representing a given audience
    ///   - tagSelector: Internal-only selector
    ///   - versionPredicate: Version predicate representing a given audience
    ///   - requiresAnalytics: Flag indicating if audience consists of users that require analytics tracking
    ///   - permissionPredicate: Flag indicating if audience consists of users that require certain permissions
    ///   - testDevices:  Array of test device identifiers representing a given audience
    ///   - hashSelector: Internal-only selector
    ///   - deviceTypes: Array of device types representing a given audience
    public init(
        newUser: Bool? = nil,
        notificationOptIn: Bool? = nil,
        locationOptIn: Bool? = nil,
        languageIDs: [String]? = nil,
        tagSelector: DeviceTagSelector? = nil,
        versionPredicate: JSONPredicate? = nil,
        requiresAnalytics: Bool? = nil,
        permissionPredicate: JSONPredicate? = nil,
        testDevices: [String]? = nil,
        hashSelector: AudienceHashSelector? = nil,
        deviceTypes: [String]? = nil
    ) {
        self.newUser = newUser
        self.notificationOptIn = notificationOptIn
        self.locationOptIn = locationOptIn
        self.languageIDs = languageIDs
        self.tagSelector = tagSelector
        self.versionPredicate = versionPredicate
        self.requiresAnalytics = requiresAnalytics
        self.permissionPredicate = permissionPredicate
        self.testDevices = testDevices
        self.hashSelector = hashSelector
        self.deviceTypes = deviceTypes
    }
}

