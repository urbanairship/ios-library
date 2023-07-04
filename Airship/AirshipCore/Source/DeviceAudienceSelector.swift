import Foundation

// NOTE: For internal use only. :nodoc:
struct DeviceAudienceSelector: Sendable, Codable {
    public var newUser: Bool?
    public var notificationOptIn: Bool?
    public var locationOptIn: Bool?
    public var languageIDs: [String]?
    public var tagSelector: DeviceTagSelector?
    public var requiresAnalytics: Bool?
    public var permissionPredicate: JSONPredicate?
    public var versionPredicate: JSONPredicate?
    public var testDevices: [String]?
    public var hashSelector: AudienceHashSelector?

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
    }

    init(newUser: Bool? = nil, notificationOptIn: Bool? = nil, locationOptIn: Bool? = nil, languageIDs: [String]? = nil, tagSelector: DeviceTagSelector? = nil, versionPredicate: JSONPredicate? = nil, requiresAnalytics: Bool? = nil, permissionPredicate: JSONPredicate? = nil, testDevices: [String]? = nil, hashSelector: AudienceHashSelector? = nil) {
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
    }
}


extension DeviceAudienceSelector {
    
    func evaluate(
        newUserEvaluationDate: Date = Date.distantPast,
        contactID: String? = nil,
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

        guard checkLocale(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Locale condition not met for audience: \(self)")
            return false
        }

        guard await checkTags(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Tags condition not met for audience: \(self)")
            return false
        }

        guard checkTestDevices(deviceInfoProvider: deviceInfoProvider) else {
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

        guard await checkHash(deviceInfoProvider: deviceInfoProvider, contactID: contactID) else {
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


    private func checkTestDevices(deviceInfoProvider: AudienceDeviceInfoProvider) -> Bool {
        guard let testDevices = self.testDevices else {
            return true
        }

        guard let channel = deviceInfoProvider.channelID else {
            return false
        }

        let digest = AirshipUtils.sha256Digest(input: channel).subdata(with: NSMakeRange(0, 16))
        return testDevices.contains { testDevice in
            Base64.dataFromString(testDevice) == digest
        }
    }

    private func checkLocale(deviceInfoProvider: AudienceDeviceInfoProvider) -> Bool {
        guard let languageIDs = self.languageIDs else {
            return true
        }

        let currentLocale = deviceInfoProvider.locale
        return languageIDs.contains { languageID in
            let locale = Locale(identifier: languageID)

            if currentLocale.languageCode != locale.languageCode {
                return false
            }

            if (locale.regionCode != nil && locale.regionCode != currentLocale.regionCode) {
                return false
            }

            return true
        }
    }

    private func checkHash(deviceInfoProvider: AudienceDeviceInfoProvider, contactID: String?) async -> Bool {
        guard let hash = self.hashSelector else {
            return true
        }

        let contactID = await resolveContactID(deviceInfoProvider: deviceInfoProvider, contactID: contactID)
        guard let channelID = deviceInfoProvider.channelID else {
            return false
        }

        return hash.evaluate(channelID: channelID, contactID: contactID)
    }

    private func resolveContactID(deviceInfoProvider: AudienceDeviceInfoProvider, contactID: String?) async -> String {
        if let contactID = contactID {
            return contactID
        }

        return await deviceInfoProvider.stableContactID
    }
}

protocol AudienceDeviceInfoProvider: AnyObject {
    var isAirshipReady: Bool { get }
    var tags: Set<String> { get }
    var channelID: String? { get }
    var locale:  Locale { get }
    var appVersion:  String? { get }
    var permissions:  [AirshipPermission: AirshipPermissionStatus] { get async }
    var isUserOptedInPushNotifications: Bool { get async }
    var analyticsEnabled: Bool { get }
    var installDate: Date { get }
    var stableContactID: String { get async }
}

final class DefaultAudienceDeviceInfoProvider: AudienceDeviceInfoProvider {

    var installDate: Date {
        Airship.shared.installDate
    }

    var stableContactID: String {
        get async {
            return await Airship.contact.getStableContactID()
        }
    }

    var appVersion: String? {
        return AirshipUtils.bundleShortVersionString()
    }

    var isAirshipReady: Bool {
        return Airship.isFlying
    }

    var tags: Set<String> {
        return Set(Airship.channel.tags)
    }

    var channelID: String? {
        return Airship.channel.identifier
    }

    var locale: Locale {
        return Airship.shared.localeManager.currentLocale
    }

    var permissions: [AirshipPermission : AirshipPermissionStatus] {
        get async {
            var results: [AirshipPermission : AirshipPermissionStatus] = [:]
            for permission in Airship.shared.permissionsManager.configuredPermissions {
                results[permission] = await Airship.shared.permissionsManager.checkPermissionStatus(permission)
            }
            return results
        }
    }

    var isUserOptedInPushNotifications: Bool {
        get async {
            return await Airship.push.notificationStatus.isUserOptedIn
        }
    }

    var analyticsEnabled: Bool {
        return Airship.shared.privacyManager.isEnabled(.analytics)
    }
}
