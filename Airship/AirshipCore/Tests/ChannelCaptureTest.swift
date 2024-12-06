/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class ChannelCaptureTest: XCTestCase {

    private var config: AirshipConfig = AirshipConfig()
    private let channel: TestChannel = TestChannel()
    private let pasteboard: TestPasteboard = TestPasteboard()
    private let notificationCenter: NotificationCenter = NotificationCenter()
    private let date: UATestDate = UATestDate()
    private var channelCapture: ChannelCapture!

    override func setUpWithError() throws {
        self.date.dateOverride = Date()
        self.config.isChannelCaptureEnabled = true
        self.channel.identifier = UUID().uuidString

        self.channelCapture = ChannelCapture(
            config: .testConfig(),
            channel: channel,
            notificationCenter: notificationCenter,
            date: date,
            pasteboard: pasteboard
        )
    }

    func testCapture() throws {
        knock(times: 6)

        let (text, expiry) = self.pasteboard.lastCopy!

        XCTAssertEqual("ua:\(self.channel.identifier!)", text)
        XCTAssertEqual(expiry, 60)
    }

    func testCaptureNilIdentifier() throws {
        self.channel.identifier = nil
        knock(times: 6)

        let (text, expiry) = self.pasteboard.lastCopy!

        XCTAssertEqual("ua:", text)
        XCTAssertEqual(expiry, 60)
    }

    func testKnock() throws {
        knock(times: 5)
        XCTAssertNil(self.pasteboard.lastCopy)
        self.date.offset += 30
        XCTAssertNil(self.pasteboard.lastCopy)
        knock(times: 1)
        XCTAssertNotNil(self.pasteboard.lastCopy)
    }

    func testKnockTooSlow() throws {
        knock(times: 5)
        XCTAssertNil(self.pasteboard.lastCopy)
        self.date.offset += 31
        XCTAssertNil(self.pasteboard.lastCopy)
        knock(times: 1)
        XCTAssertNil(self.pasteboard.lastCopy)
    }

    private func knock(times: UInt = 1) {
        for _ in 1...times {
            self.notificationCenter.post(
                name: AppStateTracker.didTransitionToForeground,
                object: nil
            )
        }
    }
}

final class TestPasteboard: AirshipPasteboardProtocol, @unchecked Sendable {
    var lastCopy: (String, TimeInterval)?
    func copy(value: String, expiry: TimeInterval) {
        lastCopy = (value, expiry)
    }
}
