/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class ChannelRegistrationPayloadTest: XCTestCase {

    private lazy var fullPayload: ChannelRegistrationPayload = {
        let quietTime = ChannelRegistrationPayload.QuietTime(
            start: "16:00",
            end: "16:01"
        )
        var fullPayload = ChannelRegistrationPayload()
        fullPayload.identityHints = ChannelRegistrationPayload.IdentityHints()
        fullPayload.channel.iOSChannelSettings = ChannelRegistrationPayload.iOSChannelSettings()

        // set up the full payload
        fullPayload.channel.isOptedIn = true
        fullPayload.channel.isBackgroundEnabled = true
        fullPayload.channel.pushAddress = "FAKEADDRESS"
        fullPayload.identityHints?.userID = "fakeUser"
        fullPayload.channel.contactID = "some-contact-id"
        fullPayload.channel.iOSChannelSettings?.badge = 1
        fullPayload.channel.iOSChannelSettings?.quietTime = quietTime
        fullPayload.channel.iOSChannelSettings?.quietTimeTimeZone = "quietTimeTimeZone"
        fullPayload.channel.timeZone = "timezone"
        fullPayload.channel.language = "language"
        fullPayload.channel.country = "country"
        fullPayload.channel.tags = ["tagOne", "tagTwo"]
        fullPayload.channel.setTags = true
        fullPayload.channel.sdkVersion = "SDKVersion"
        fullPayload.channel.appVersion = "appVersion"
        fullPayload.channel.deviceModel = "deviceModel"
        fullPayload.channel.deviceOS = "deviceOS"
        fullPayload.channel.carrier = "carrier"

        return fullPayload
    }()

    func testMinimalUpdatePayloadSameValues() {
        let minPayload = self.fullPayload.minimizePayload(
            previous: self.fullPayload
        )

        var expected = self.fullPayload
        expected.channel.appVersion = nil
        expected.channel.deviceModel = nil
        expected.channel.setTags = false
        expected.channel.tags = nil
        expected.channel.carrier = nil
        expected.channel.country = nil
        expected.channel.language = nil
        expected.channel.deviceOS = nil
        expected.channel.timeZone = nil
        expected.channel.sdkVersion = nil
        expected.identityHints = nil
        expected.channel.iOSChannelSettings?.isTimeSensitive = nil
        expected.channel.iOSChannelSettings?.isScheduledSummary = nil

        XCTAssertEqual(expected, minPayload)
    }

    func testMinimalUpdateDifferentValues() {
        var otherPayload = self.fullPayload
        otherPayload.channel.appVersion = UUID().uuidString
        otherPayload.channel.deviceModel = UUID().uuidString
        otherPayload.channel.tags = ["some other tag"]
        otherPayload.channel.carrier = UUID().uuidString
        otherPayload.channel.country = UUID().uuidString
        otherPayload.channel.language = UUID().uuidString
        otherPayload.channel.deviceOS = UUID().uuidString
        otherPayload.channel.timeZone = UUID().uuidString
        otherPayload.channel.sdkVersion = UUID().uuidString
        otherPayload.identityHints?.userID = UUID().uuidString
        otherPayload.channel.iOSChannelSettings?.isTimeSensitive = true
        otherPayload.channel.iOSChannelSettings?.isScheduledSummary = true

        let minPayload = otherPayload.minimizePayload(
            previous: self.fullPayload
        )

        var expected = otherPayload
        expected.identityHints = nil
        expected.channel.tagChanges = ChannelRegistrationPayload.TagChanges(
            adds: otherPayload.channel.tags!,
            removes: fullPayload.channel.tags!
        )

        XCTAssertEqual(expected, minPayload)
    }

    func testMinimalUpdateDifferentContact() {
        var otherPayload = self.fullPayload
        otherPayload.channel.contactID = UUID().uuidString

        let minPayload = otherPayload.minimizePayload(
            previous: self.fullPayload
        )

        var expected = otherPayload
        expected.channel.setTags = false
        expected.channel.tags = nil
        expected.identityHints = nil
        expected.channel.iOSChannelSettings?.isTimeSensitive = nil
        expected.channel.iOSChannelSettings?.isScheduledSummary = nil

        XCTAssertEqual(expected, minPayload)
    }
}
