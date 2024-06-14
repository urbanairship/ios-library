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

/// NOTE: For internal use only. :nodoc:
public extension DeviceAudienceSelector {

    func evaluate(
        newUserEvaluationDate: Date = Date.distantPast,
        deviceInfoProvider: AudienceDeviceInfoProvider = DefaultAudienceDeviceInfoProvider()
    ) async throws -> Bool {

        AirshipLogger.trace("Evaluating audience conditions \(self)")

        guard deviceInfoProvider.isAirshipReady else {
            throw AirshipErrors.error("Airship not ready, unable to check audience")
        }

        guard checkNewUser(deviceInfoProvider: deviceInfoProvider, newUserEvaluationDate: newUserEvaluationDate) else {
            AirshipLogger.trace("Locale condition not met for audience: \(self)")
            return false
        }

        guard checkDeviceTypes() else {
            AirshipLogger.trace("Device type condition not met for audience: \(self)")
            return false
        }

        guard checkLocale(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Locale condition not met for audience: \(self)")
            return false
        }

        guard await checkTags(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Tags condition not met for audience: \(self)")
            return false
        }

        guard try await checkTestDevices(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Test device condition not met for audience: \(self)")
            return false
        }

        guard try checkVersion(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("App version condition not met for audience: \(self)")
            return false
        }

        guard checkAnalytics(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Analytics condition not met for audience: \(self)")
            return false
        }

        guard await checkNotificationOptIn(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Notification opt-in condition not met for audience: \(self)")
            return false
        }

        guard try await checkPermissions(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Permission condition not met for audience: \(self)")
            return false
        }

        guard try await checkHash(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Hash condition not met for audience: \(self)")
            return false
        }

        return true
    }

    private func checkNewUser(deviceInfoProvider: AudienceDeviceInfoProvider, newUserEvaluationDate: Date) -> Bool {
        guard let newUser = self.newUser else {
            return true
        }

        return newUser == (deviceInfoProvider.installDate >= newUserEvaluationDate)
    }

    private func checkDeviceTypes() -> Bool {
        return deviceTypes?.contains("ios") ?? true
    }

    private func checkPermissions(deviceInfoProvider: AudienceDeviceInfoProvider) async throws -> Bool {
        guard self.permissionPredicate != nil || self.locationOptIn != nil else {
            return true
        }

        let permissions = await deviceInfoProvider.permissions
        if let permissionPredicate = self.permissionPredicate {
            var map: [String: String] = [:]
            for entry in permissions {
                map[entry.key.stringValue] = entry.value.stringValue
            }


            guard permissionPredicate.evaluate(map) else {
                return false
            }
        }

        if let locationOptIn = self.locationOptIn {
            let isLocationPermissionGranted = permissions[.location] == .granted
            return locationOptIn == isLocationPermissionGranted
        }

        return true
    }

    private func checkAnalytics(deviceInfoProvider: AudienceDeviceInfoProvider) -> Bool {
        guard let requiresAnalytics = self.requiresAnalytics else {
            return true
        }

        return requiresAnalytics == false || deviceInfoProvider.analyticsEnabled
    }

    private func checkVersion(deviceInfoProvider: AudienceDeviceInfoProvider) throws -> Bool {
        guard let versionPredicate = self.versionPredicate else {
            return true
        }

        guard let appVersion = deviceInfoProvider.appVersion else {
            AirshipLogger.trace("Unable to query app version for audience: \(self)")
            return false
        }

        let versionObject = [ "ios": [ "version": appVersion] ]
        return versionPredicate.evaluate(versionObject)
    }


    private func checkTags(deviceInfoProvider: AudienceDeviceInfoProvider) async -> Bool {
        guard let tagSelector = self.tagSelector else {
            return true
        }

        return tagSelector.evaluate(tags: deviceInfoProvider.tags)
    }

    private func checkNotificationOptIn(deviceInfoProvider: AudienceDeviceInfoProvider) async -> Bool {
        guard let notificationOptIn = self.notificationOptIn else {
            return true
        }

        return await deviceInfoProvider.isUserOptedInPushNotifications == notificationOptIn
    }


    private func checkTestDevices(deviceInfoProvider: AudienceDeviceInfoProvider) async throws -> Bool {
        guard let testDevices = self.testDevices else {
            return true
        }


        guard deviceInfoProvider.isChannelCreated else {
            return false
        }

        let channelID = try await deviceInfoProvider.channelID
        let digest = AirshipUtils.sha256Digest(input: channelID).subdata(with: NSMakeRange(0, 16))
        return testDevices.contains { testDevice in
            AirshipBase64.data(from: testDevice) == digest
        }
    }

    private func checkLocale(deviceInfoProvider: AudienceDeviceInfoProvider) -> Bool {
        guard let languageIDs = self.languageIDs else {
            return true
        }

        let currentLocale = deviceInfoProvider.locale
        return languageIDs.contains { languageID in
            let locale = Locale(identifier: languageID)

            if currentLocale.getLanguageCode() != locale.getLanguageCode() {
                return false
            }

            if (!locale.getRegionCode().isEmpty && locale.getRegionCode() != currentLocale.getRegionCode()) {
                return false
            }

            return true
        }
    }

    private func checkHash(deviceInfoProvider: AudienceDeviceInfoProvider) async throws -> Bool {
        guard let hash = self.hashSelector else {
            return true
        }

        let contactID = await deviceInfoProvider.stableContactInfo.contactID
        let channelID = try await deviceInfoProvider.channelID


        return hash.evaluate(channelID: channelID, contactID: contactID)
    }

}
