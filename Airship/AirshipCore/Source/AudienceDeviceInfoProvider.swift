/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
public protocol AudienceDeviceInfoProvider: AnyObject, Sendable {
    var isAirshipReady: Bool { get }
    var tags: Set<String> { get }
    var channelID: String? { get }
    var locale:  Locale { get }
    var appVersion: String? { get }
    var permissions: [AirshipPermission: AirshipPermissionStatus] { get async }
    var isUserOptedInPushNotifications: Bool { get async }
    var analyticsEnabled: Bool { get }
    var installDate: Date { get }
    var stableContactID: String { get async }
}

// NOTE: For internal use only. :nodoc:
public final class CachingAudienceDeviceInfoProvider: AudienceDeviceInfoProvider, @unchecked Sendable {
    private let deviceInfoProvider: AudienceDeviceInfoProvider

    private let cachedTags: OneTimeValue<Set<String>>
    private let cachedLocale: OneTimeValue<Locale>
    private let cachedContactID: OneTimeAsyncValue<String>
    private let cachedPermissions: OneTimeAsyncValue<[AirshipPermission : AirshipPermissionStatus]>
    private let cachedIsUserOptedInPushNotifications: OneTimeAsyncValue<Bool>
    private let cachedAnalyticsEnabled: OneTimeValue<Bool>

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
    }

    public var installDate: Date {
        Airship.shared.installDate
    }

    public var stableContactID: String {
        get async {
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


// NOTE: For internal use only. :nodoc:
public final class DefaultAudienceDeviceInfoProvider: AudienceDeviceInfoProvider {

    public init() {}
    
    public var installDate: Date {
        Airship.shared.installDate
    }

    public var stableContactID: String {
        get async {
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
    private var _value: T?
    private var provider: () -> T

    init(provider: @escaping () -> T) {
        self.provider = provider
    }

    var value: T {
        get {
            var value: T!
            lock.sync {
                if let _value = _value {
                    value = _value
                } else {
                    value = provider()
                    _value = value
                }
            }
            return value
        }
    }
}

fileprivate final class OneTimeAsyncValue<T: Equatable & Sendable>: @unchecked Sendable {
    private let queue = SerialQueue()
    private var _value: T?
    private var provider: @Sendable () async -> T

    init(provider: @Sendable @escaping () async -> T) {
        self.provider = provider
    }

    var value: T {
        get async {
            return await queue.runSafe {
                if let _value = self._value {
                    return _value
                } else {
                    let value = await self.provider()
                    self._value = value
                    return value
                }
            }
        }
    }
}
