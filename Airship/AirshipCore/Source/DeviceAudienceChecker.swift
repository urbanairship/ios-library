/* Copyright Airship and Contributors */



/// NOTE: For internal use only. :nodoc:
public protocol DeviceAudienceChecker: Sendable {
    func evaluate(
        audienceSelector: CompoundDeviceAudienceSelector?,
        newUserEvaluationDate: Date,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> AirshipDeviceAudienceResult
}

/// NOTE: For internal use only. :nodoc:
struct DefaultDeviceAudienceChecker: DeviceAudienceChecker {
    private let hashChecker: HashChecker

    public init(cache: any AirshipCache) {
        self.hashChecker = HashChecker(cache: cache)
    }

    public func evaluate(
        audienceSelector: CompoundDeviceAudienceSelector?,
        newUserEvaluationDate: Date,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> AirshipDeviceAudienceResult {
        guard let audienceSelector else {
            return .match
        }

        return try await audienceSelector.evaluate(
            newUserEvaluationDate: newUserEvaluationDate,
            deviceInfoProvider: deviceInfoProvider,
            hashChecker: hashChecker
        )
    }
}


extension Array where Element == AirshipDeviceAudienceResult {

    func reducedResult(reducer: (Bool, Bool) -> Bool) -> AirshipDeviceAudienceResult {
        var isMatch: Bool?
        var reportingMetadata: [AirshipJSON]? = nil

        self.forEach {
            isMatch = if let isMatch {
                reducer(isMatch, $0.isMatch)
            } else {
                $0.isMatch
            }

            if let reporting = $0.reportingMetadata {
                if (reportingMetadata == nil) {
                    reportingMetadata = []
                }
                reportingMetadata?.append(contentsOf: reporting)
            }
        }

        return AirshipDeviceAudienceResult(
            isMatch: isMatch ?? true,
            reportingMetadata: reportingMetadata
        )
    }
}

extension CompoundDeviceAudienceSelector {
    func evaluate(
        newUserEvaluationDate: Date = Date.distantPast,
        deviceInfoProvider: any AudienceDeviceInfoProvider = DefaultAudienceDeviceInfoProvider(),
        hashChecker: HashChecker
    ) async throws -> AirshipDeviceAudienceResult {
        switch self {
        case .atomic(let audience):
            return try await audience.evaluate(
                newUserEvaluationDate: newUserEvaluationDate,
                deviceInfoProvider: deviceInfoProvider,
                hashChecker: hashChecker
            )

        case .not(let selector):
            var result = try await selector.evaluate(
                newUserEvaluationDate: newUserEvaluationDate,
                deviceInfoProvider: deviceInfoProvider,
                hashChecker: hashChecker
            )

            result.negate()
            return result

        case .and(let selectors):
            guard !selectors.isEmpty else {
                return AirshipDeviceAudienceResult.match
            }

            var results: [AirshipDeviceAudienceResult] = []
            for selector in selectors {
                let selectorResult = try await selector.evaluate(
                    newUserEvaluationDate: newUserEvaluationDate,
                    deviceInfoProvider: deviceInfoProvider,
                    hashChecker: hashChecker
                )
                results.append(selectorResult)
                if !selectorResult.isMatch {
                    break
                }
            }
            return results.reducedResult { first, second in first && second }

        case .or(let selectors):
            guard !selectors.isEmpty else {
                return AirshipDeviceAudienceResult.miss
            }

            var results: [AirshipDeviceAudienceResult] = []
            for selector in selectors {
                let selectorResult = try await selector.evaluate(
                    newUserEvaluationDate: newUserEvaluationDate,
                    deviceInfoProvider: deviceInfoProvider,
                    hashChecker: hashChecker
                )

                results.append(selectorResult)
                if selectorResult.isMatch {
                    break
                }
            }

            return results.reducedResult { first, second in first || second }
        }
    }
}


/// NOTE: For internal use only. :nodoc:
extension DeviceAudienceSelector {

    func evaluate(
        newUserEvaluationDate: Date = Date.distantPast,
        deviceInfoProvider: any AudienceDeviceInfoProvider = DefaultAudienceDeviceInfoProvider(),
        hashChecker: HashChecker
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

        let hashCheckerResult = try await hashChecker.evaluate(
            hashSelector: self.hashSelector,
            deviceInfoProvider: deviceInfoProvider
        )

        if !hashCheckerResult.isMatch {
            AirshipLogger.trace("Hash condition not met for audience: \(self)")
        }

        return hashCheckerResult
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
            var map: [String: AirshipJSON] = [:]
            for entry in permissions {
                map[entry.key.rawValue] = AirshipJSON.string(entry.value.rawValue)
            }

            guard permissionPredicate.evaluate(json: .object(map)) else {
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

        let versionObject = AirshipJSON.object(
            ["ios": .object(["version": .string(appVersion)])]
        )
        return versionPredicate.evaluate(json: versionObject)
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

}
