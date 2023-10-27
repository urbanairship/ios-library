/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol AudienceDeviceInfoProvider: AnyObject, Sendable {
    var isAirshipReady: Bool { get }
    var tags: Set<String> { get }
    var channelID: String? { get }
    var locale:  Locale { get }
    var appVersion: String? { get }
    var sdkVersion: String { get }
    var permissions: [AirshipPermission: AirshipPermissionStatus] { get async }
    var isUserOptedInPushNotifications: Bool { get async }
    var analyticsEnabled: Bool { get }
    var installDate: Date { get }
    var stableContactID: String { get async }
}

/// NOTE: For internal use only. :nodoc:
public final class CachingAudienceDeviceInfoProvider: AudienceDeviceInfoProvider, @unchecked Sendable {
    private let deviceInfoProvider: AudienceDeviceInfoProvider

    private let cachedTags: OneTimeValue<Set<String>>
    private let cachedLocale: OneTimeValue<Locale>
    private let cachedContactID: OneTimeAsyncValue<String>
    private let cachedChannelID: OneTimeValue<String?>
    private let cachedPermissions: OneTimeAsyncValue<[AirshipPermission : AirshipPermissionStatus]>
    private let cachedIsUserOptedInPushNotifications: OneTimeAsyncValue<Bool>
    private let cachedAnalyticsEnabled: OneTimeValue<Bool>

    public convenience init(contactID: String?) {
        self.init(deviceInfoProvider: DefaultAudienceDeviceInfoProvider(contactID: contactID))
    }

    public init(deviceInfoProvider: AudienceDeviceInfoProvider = DefaultAudienceDeviceInfoProvider()) {
        self.deviceInfoProvider = deviceInfoProvider

        self.cachedTags = OneTimeValue {
            return deviceInfoProvider.tags
        }

        self.cachedLocale = OneTimeValue {
            return deviceInfoProvider.locale
        }

        self.cachedContactID = OneTimeAsyncValue {
            return await deviceInfoProvider.stableContactID
        }

        self.cachedPermissions = OneTimeAsyncValue {
            return await deviceInfoProvider.permissions
        }

        self.cachedIsUserOptedInPushNotifications = OneTimeAsyncValue {
            return await deviceInfoProvider.isUserOptedInPushNotifications
        }

        self.cachedAnalyticsEnabled = OneTimeValue {
            return deviceInfoProvider.analyticsEnabled
        }

        self.cachedChannelID = OneTimeValue {
            return deviceInfoProvider.channelID
        }
    }

    public var installDate: Date {
        deviceInfoProvider.installDate
    }

    public var stableContactID: String {
        get async {
            return await cachedContactID.value
        }
    }

    public var sdkVersion: String {
        return deviceInfoProvider.sdkVersion
    }

    public var appVersion: String? {
        return deviceInfoProvider.appVersion
    }

    public var isAirshipReady: Bool {
        return deviceInfoProvider.isAirshipReady
    }

    public var tags: Set<String> {
        return cachedTags.value
    }

    public var channelID: String? {
        return cachedChannelID.value
    }

    public var locale: Locale {
        return cachedLocale.value
    }

    public var permissions: [AirshipPermission : AirshipPermissionStatus] {
        get async {
            await cachedPermissions.value
        }
    }

    public var isUserOptedInPushNotifications: Bool {
        get async {
            return await cachedIsUserOptedInPushNotifications.value
        }
    }

    public var analyticsEnabled: Bool {
        return cachedAnalyticsEnabled.value
    }

}


/// NOTE: For internal use only. :nodoc:
public final class DefaultAudienceDeviceInfoProvider: AudienceDeviceInfoProvider {

    private let contactID: String?

    public init(contactID: String? = nil) {
        self.contactID = contactID
    }

    public var installDate: Date {
        Airship.shared.installDate
    }

    public var sdkVersion: String {
        AirshipVersion.get()
    }

    public var stableContactID: String {
        get async {
            if let contactID = self.contactID {
                return contactID
            }
            return await Airship.contact.getStableContactID()
        }
    }

    public var appVersion: String? {
        return AirshipUtils.bundleShortVersionString()
    }

    public var isAirshipReady: Bool {
        return Airship.isFlying
    }

    public var tags: Set<String> {
        return Set(Airship.channel.tags)
    }

    public var channelID: String? {
        return Airship.channel.identifier
    }

    public var locale: Locale {
        return Airship.shared.localeManager.currentLocale
    }

    public var permissions: [AirshipPermission : AirshipPermissionStatus] {
        get async {
            var results: [AirshipPermission : AirshipPermissionStatus] = [:]
            for permission in Airship.shared.permissionsManager.configuredPermissions {
                results[permission] = await Airship.shared.permissionsManager.checkPermissionStatus(permission)
            }
            return results
        }
    }

    public var isUserOptedInPushNotifications: Bool {
        get async {
            return await Airship.push.notificationStatus.isUserOptedIn
        }
    }

    public var analyticsEnabled: Bool {
        return Airship.shared.privacyManager.isEnabled(.analytics)
    }
}


fileprivate final class OneTimeValue<T: Equatable & Sendable>: @unchecked Sendable {
    private let lock = AirshipLock()
    private var atomicValue: Atomic<T?> = Atomic(nil)
    private var provider: () -> T

    var cachedValue: T? {
        get {
            return atomicValue.value
        }
    }

    init(provider: @escaping () -> T) {
        self.provider = provider
    }

    var value: T {
        get {
            var value: T!
            lock.sync {
                if let cachedValue = atomicValue.value {
                    value = cachedValue
                } else {
                    value = provider()
                    atomicValue.value = value
                }
            }
            return value
        }
    }
}

fileprivate final class OneTimeAsyncValue<T: Equatable & Sendable>: @unchecked Sendable {
    private let queue = SerialQueue()
    private var atomicValue: Atomic<T?> = Atomic(nil)
    private var provider: @Sendable () async -> T

    var cachedValue: T? {
        get {
            return atomicValue.value
        }
    }

    init(provider: @Sendable @escaping () async -> T) {
        self.provider = provider
    }

    var value: T {
        get async {
            return await queue.runSafe {
                if let cached = self.atomicValue.value {
                    return cached
                } else {
                    let newValue = await self.provider()
                    self.atomicValue.value = newValue
                    return newValue
                }
            }
        }
    }
}
