/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol DeviceAudienceChecker: Sendable {
    func evaluate(
        audienceSelector: CompoundDeviceAudienceSelector?,
        newUserEvaluationDate: Date,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> AirshipDeviceAudienceResult
}

/// NOTE: For internal use only. :nodoc:
public struct AirshipDeviceAudienceResult: Sendable {
    public var isMatch: Bool

    fileprivate mutating func negate() {
        isMatch = !isMatch
    }

    public static let match: AirshipDeviceAudienceResult = .init(isMatch: true)
    public static let miss: AirshipDeviceAudienceResult = .init(isMatch: false)
}

struct DefaultDeviceAudienceChecker: DeviceAudienceChecker {
    init() {}

    func evaluate(
        audienceSelector: CompoundDeviceAudienceSelector?,
        newUserEvaluationDate: Date,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> AirshipDeviceAudienceResult {
        guard let audienceSelector else {
            return .match
        }

        return try await audienceSelector.evaluate(
            newUserEvaluationDate: newUserEvaluationDate,
            deviceInfoProvider: deviceInfoProvider
        )
    }
}


extension CompoundDeviceAudienceSelector {
    func evaluate(
        newUserEvaluationDate: Date = Date.distantPast,
        deviceInfoProvider: any AudienceDeviceInfoProvider = DefaultAudienceDeviceInfoProvider()
    ) async throws -> AirshipDeviceAudienceResult {
        switch self {
        case .atomic(let audience):
            return try await audience.evaluate(
                newUserEvaluationDate: newUserEvaluationDate,
                deviceInfoProvider: deviceInfoProvider
            )

        case .not(let selector):
            var result = try await selector.evaluate(
                newUserEvaluationDate: newUserEvaluationDate,
                deviceInfoProvider: deviceInfoProvider
            )

            result.negate()
            return result

        case .and(let selectors):
            var results: [AirshipDeviceAudienceResult] = []
            for selector in selectors {
                let selectorResult = try await selector.evaluate(
                    newUserEvaluationDate: newUserEvaluationDate,
                    deviceInfoProvider: deviceInfoProvider
                )
                results.append(selectorResult)
                if !selectorResult.isMatch {
                    break
                }
            }

            // Combine results
            let isMatch = results.allSatisfy { result in
                result.isMatch
            }

            return AirshipDeviceAudienceResult(isMatch: isMatch)


        case .or(let selectors):
            var results: [AirshipDeviceAudienceResult] = []
            for selector in selectors {
                let selectorResult = try await selector.evaluate(
                    newUserEvaluationDate: newUserEvaluationDate,
                    deviceInfoProvider: deviceInfoProvider
                )

                results.append(selectorResult)
                if selectorResult.isMatch {
                    break
                }
            }

            // Combine results
            let isMatch = results.isEmpty || results.contains { result in
                result.isMatch
            }

            return AirshipDeviceAudienceResult(isMatch: isMatch)
        }
    }
}


/// NOTE: For internal use only. :nodoc:
extension DeviceAudienceSelector {

    func evaluate(
        newUserEvaluationDate: Date = Date.distantPast,
        deviceInfoProvider: any AudienceDeviceInfoProvider = DefaultAudienceDeviceInfoProvider()
    ) async throws -> AirshipDeviceAudienceResult {

        AirshipLogger.trace("Evaluating audience conditions \(self)")

        guard deviceInfoProvider.isAirshipReady else {
            throw AirshipErrors.error("Airship not ready, unable to check audience")
        }

        guard checkNewUser(deviceInfoProvider: deviceInfoProvider, newUserEvaluationDate: newUserEvaluationDate) else {
            AirshipLogger.trace("Locale condition not met for audience: \(self)")
            return .miss
        }

        guard checkDeviceTypes() else {
            AirshipLogger.trace("Device type condition not met for audience: \(self)")
            return .miss
        }

        guard checkLocale(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Locale condition not met for audience: \(self)")
            return .miss
        }

        guard await checkTags(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Tags condition not met for audience: \(self)")
            return .miss
        }

        guard try await checkTestDevices(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Test device condition not met for audience: \(self)")
            return .miss
        }

        guard try checkVersion(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("App version condition not met for audience: \(self)")
            return .miss
        }

        guard checkAnalytics(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Analytics condition not met for audience: \(self)")
            return .miss
        }

        guard await checkNotificationOptIn(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Notification opt-in condition not met for audience: \(self)")
            return .miss
        }

        guard try await checkPermissions(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Permission condition not met for audience: \(self)")
            return .miss
        }

        guard try await checkHash(deviceInfoProvider: deviceInfoProvider) else {
            AirshipLogger.trace("Hash condition not met for audience: \(self)")
            return .miss
        }

        return .match
    }

    private func checkNewUser(deviceInfoProvider: any AudienceDeviceInfoProvider, newUserEvaluationDate: Date) -> Bool {
        guard let newUser = self.newUser else {
            return true
        }

        return newUser == (deviceInfoProvider.installDate >= newUserEvaluationDate)
    }

    private func checkDeviceTypes() -> Bool {
        return deviceTypes?.contains("ios") ?? true
    }

    private func checkPermissions(deviceInfoProvider: any AudienceDeviceInfoProvider) async throws -> Bool {
        guard self.permissionPredicate != nil || self.locationOptIn != nil else {
            return true
        }

        let permissions = await deviceInfoProvider.permissions
        if let permissionPredicate = self.permissionPredicate {
            var map: [String: String] = [:]
            for entry in permissions {
                map[entry.key.rawValue] = entry.value.rawValue
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

    private func checkAnalytics(deviceInfoProvider: any AudienceDeviceInfoProvider) -> Bool {
        guard let requiresAnalytics = self.requiresAnalytics else {
            return true
        }

        return requiresAnalytics == false || deviceInfoProvider.analyticsEnabled
    }

    private func checkVersion(deviceInfoProvider: any AudienceDeviceInfoProvider) throws -> Bool {
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


    private func checkTags(deviceInfoProvider: any AudienceDeviceInfoProvider) async -> Bool {
        guard let tagSelector = self.tagSelector else {
            return true
        }

        return tagSelector.evaluate(tags: deviceInfoProvider.tags)
    }

    private func checkNotificationOptIn(deviceInfoProvider: any AudienceDeviceInfoProvider) async -> Bool {
        guard let notificationOptIn = self.notificationOptIn else {
            return true
        }

        return await deviceInfoProvider.isUserOptedInPushNotifications == notificationOptIn
    }


    private func checkTestDevices(deviceInfoProvider: any AudienceDeviceInfoProvider) async throws -> Bool {
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

    private func checkLocale(deviceInfoProvider: any AudienceDeviceInfoProvider) -> Bool {
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

    private func checkHash(deviceInfoProvider: any AudienceDeviceInfoProvider) async throws -> Bool {
        guard let hash = self.hashSelector else {
            return true
        }

        let contactID = await deviceInfoProvider.stableContactInfo.contactID
        let channelID = try await deviceInfoProvider.channelID


        return hash.evaluate(channelID: channelID, contactID: contactID)
    }

}
