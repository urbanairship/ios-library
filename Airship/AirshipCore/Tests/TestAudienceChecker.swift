/* Copyright Airship and Contributors */

import Foundation

@testable
import AirshipCore

final class TestAudienceChecker: DeviceAudienceChecker, @unchecked Sendable {
    func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        deviceInfoProvider: AirshipCore.AudienceDeviceInfoProvider
    ) async throws -> Bool {
        return try await self.onEvaluate?(audience, newUserEvaluationDate, deviceInfoProvider) ?? false
    }

    var onEvaluate: ((DeviceAudienceSelector, Date,  AudienceDeviceInfoProvider) async throws -> Bool)!
}

final class TestAudienceDeviceInfoProvider: AudienceDeviceInfoProvider, @unchecked Sendable {
    var sdkVersion: String = AirshipVersion.get()
    
    var isAirshipReady: Bool = true

    var tags: Set<String> = Set()

    var channelID: String? = nil

    var locale: Locale = Locale.current

    var appVersion: String? = nil

    var permissions: [AirshipPermission : AirshipPermissionStatus] = [:]

    var isUserOptedInPushNotifications: Bool = false

    var analyticsEnabled: Bool = false

    var installDate: Date = Date()

    var stableContactID: String = "stable"
}
