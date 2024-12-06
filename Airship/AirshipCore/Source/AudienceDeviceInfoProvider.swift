/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol AudienceDeviceInfoProvider: AnyObject, Sendable {
    var isAirshipReady: Bool { get }
    var tags: Set<String> { get }
    var channelID: String { get async throws }
    var locale:  Locale { get }
    var appVersion: String? { get }
    var sdkVersion: String { get }
    var permissions: [AirshipPermission: AirshipPermissionStatus] { get async }
    var isUserOptedInPushNotifications: Bool { get async }
    var analyticsEnabled: Bool { get }
    var installDate: Date { get }
    var stableContactInfo: StableContactInfo { get async }
    var isChannelCreated: Bool { get }
}

/// NOTE: For internal use only. :nodoc:
public final class CachingAudienceDeviceInfoProvider: AudienceDeviceInfoProvider, @unchecked Sendable {
    private let deviceInfoProvider: any AudienceDeviceInfoProvider

    private let cachedTags: OneTimeValue<Set<String>>
    private let cachedLocale: OneTimeValue<Locale>
    private let cachedStableContactInfo: OneTimeAsyncValue<StableContactInfo>
    private let cachedChannelID: ThrowingOneTimeAsyncValue<String>
    private let cachedPermissions: OneTimeAsyncValue<[AirshipPermission : AirshipPermissionStatus]>
    private let cachedIsUserOptedInPushNotifications: OneTimeAsyncValue<Bool>
    private let cachedAnalyticsEnabled: OneTimeValue<Bool>
    private let cachedIsChannelCreated: OneTimeValue<Bool>

    public convenience init(contactID: String?) {
        self.init(deviceInfoProvider: DefaultAudienceDeviceInfoProvider(contactID: contactID))
    }

    public init(deviceInfoProvider: any AudienceDeviceInfoProvider = DefaultAudienceDeviceInfoProvider()) {
        self.deviceInfoProvider = deviceInfoProvider

        self.cachedTags = OneTimeValue {
            return deviceInfoProvider.tags
        }

        self.cachedLocale = OneTimeValue {
            return deviceInfoProvider.locale
        }

        self.cachedStableContactInfo = OneTimeAsyncValue {
            return await deviceInfoProvider.stableContactInfo
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

        self.cachedIsChannelCreated = OneTimeValue {
            return deviceInfoProvider.isChannelCreated
        }

        self.cachedChannelID = ThrowingOneTimeAsyncValue {
            return try await deviceInfoProvider.channelID
        }
    }

    public var installDate: Date {
        deviceInfoProvider.installDate
    }

    public var stableContactInfo: StableContactInfo {
        get async {
            return await cachedStableContactInfo.getValue()
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

    public var channelID: String {
        get async throws {
            return try await cachedChannelID.getValue()
        }
    }


    public var isChannelCreated: Bool {
        return cachedIsChannelCreated.value
    }


    public var locale: Locale {
        return cachedLocale.value
    }

    public var permissions: [AirshipPermission : AirshipPermissionStatus] {
        get async {
            await cachedPermissions.getValue()
        }
    }

    public var isUserOptedInPushNotifications: Bool {
        get async {
            return await cachedIsUserOptedInPushNotifications.getValue()
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
        AirshipVersion.version
    }

    public var stableContactInfo: StableContactInfo {
        get async {
            let stableInfo = await Airship.requireComponent(
                ofType: (any InternalAirshipContactProtocol).self
            ).getStableContactInfo()

            if let contactID {
                if (stableInfo.contactID == contactID) {
                    return stableInfo
                }
                return StableContactInfo(contactID: contactID, namedUserID: nil)
            }
            
            return stableInfo
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

    public var isChannelCreated: Bool {
        return Airship.channel.identifier != nil
    }

    public var channelID: String {
        get async {
            if let channelID = Airship.channel.identifier {
                return channelID
            }
            for await update in Airship.channel.identifierUpdates {
                return update
            }
            return ""
        }
    }

    public var locale: Locale {
        return Airship.localeManager.currentLocale
    }

    public var permissions: [AirshipPermission : AirshipPermissionStatus] {
        get async {
            var results: [AirshipPermission : AirshipPermissionStatus] = [:]
            for permission in Airship.permissionsManager.configuredPermissions {
                results[permission] = await Airship.permissionsManager.checkPermissionStatus(permission)
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
        return Airship.privacyManager.isEnabled(.analytics)
    }
}


fileprivate final class OneTimeValue<T: Equatable & Sendable>: @unchecked Sendable {
    private let lock = AirshipLock()
    private var atomicValue: AirshipAtomicValue<T?> = AirshipAtomicValue(nil)
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

fileprivate actor OneTimeAsyncValue<T: Equatable & Sendable> {
    private var provider: @Sendable () async -> T
    private var task: Task<T, Never>?

    init(provider: @Sendable @escaping () async -> T) {
        self.provider = provider
    }

    func getValue() async -> T {
        if let task {
            return await task.value
        }
        let newTask = Task {
            return await provider()
        }
        task = newTask
        return await newTask.value
    }
}

fileprivate actor ThrowingOneTimeAsyncValue<T: Equatable & Sendable> {
    private var provider: @Sendable () async throws -> T
    private var task: Task<T, any Error>?
    private var value: T?

    init(provider: @Sendable @escaping () async throws -> T) {
        self.provider = provider
    }

    func getValue() async throws -> T {
        if let task, let value = try? await task.value {
            return value
        }

        let newTask = Task {
            return try await provider()
        }
        task = newTask
        return try await newTask.value
    }
}
