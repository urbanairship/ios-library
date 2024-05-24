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
    var channelID: String = UUID().uuidString

    var stableContactInfo: StableContactInfo = StableContactInfo(
        contactID: "stable",
        namedUserID: nil
    )

    var isChannelCreated: Bool = true

    var sdkVersion: String = AirshipVersion.version
    
    var isAirshipReady: Bool = true

    var tags: Set<String> = Set()

    var locale: Locale = Locale.current

    var appVersion: String? = nil

    var permissions: [AirshipPermission : AirshipPermissionStatus] = [:]

    var isUserOptedInPushNotifications: Bool = false

    var analyticsEnabled: Bool = false

    var installDate: Date = Date()

}
