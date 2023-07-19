/* Copyright Airship and Contributors */

import Foundation

@testable
import AirshipCore

final class TestAudienceChecker: DeviceAudienceChecker, @unchecked Sendable {

    var onEvaluate: ((DeviceAudienceSelector, Date, String?, AudienceDeviceInfoProvider) async throws -> Bool)!


    func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        contactID: String?
    ) async throws -> Bool {
        return try await self.evaluate(audience: audience, newUserEvaluationDate: newUserEvaluationDate, contactID: contactID, deviceInfoProvider: TestAudienceDeviceInfoProvider())
    }

    func evaluate(audience: DeviceAudienceSelector, newUserEvaluationDate: Date, contactID: String?, deviceInfoProvider: AudienceDeviceInfoProvider) async throws -> Bool {
        return try await self.onEvaluate?(audience, newUserEvaluationDate, contactID, deviceInfoProvider) ?? false

    }
}

final class TestAudienceDeviceInfoProvider: AudienceDeviceInfoProvider, @unchecked Sendable {
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
