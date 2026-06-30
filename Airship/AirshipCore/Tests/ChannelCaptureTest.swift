/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipCore
import Foundation

@Suite @MainActor
struct ChannelCaptureTest {

    private var config: AirshipConfig = AirshipConfig()
    private let channel: TestChannel = TestChannel()
    private let pasteboard: TestPasteboard = TestPasteboard()
    private let notificationCenter: NotificationCenter = NotificationCenter()
    private let date: UATestDate = UATestDate()
    private let channelCapture: (any AirshipChannelCapture)

    init() async throws {
        self.date.dateOverride = Date()
        self.config.isChannelCaptureEnabled = true
        self.channel.identifier = UUID().uuidString

        self.channelCapture = DefaultAirshipChannelCapture(
            config: .testConfig(),
            channel: channel,
            notificationCenter: notificationCenter,
            date: date,
            pasteboard: pasteboard
        )
    }

    @Test
    func testCapture() throws {
        knock(times: 6)

        let (text, expiry) = self.pasteboard.lastCopy!

        #expect("ua:\(self.channel.identifier!)" == text)
        #expect(expiry == 60)
    }

    @Test
    func testCaptureNilIdentifier() throws {
        self.channel.identifier = nil
        knock(times: 6)

        let (text, expiry) = self.pasteboard.lastCopy!

        #expect("ua:" == text)
        #expect(expiry == 60)
    }

    @Test
    func testKnock() throws {
        knock(times: 5)
        #expect(self.pasteboard.lastCopy == nil)
        self.date.offset += 30
        #expect(self.pasteboard.lastCopy == nil)
        knock(times: 1)
        #expect(self.pasteboard.lastCopy != nil)
    }

    @Test
    func testKnockTooSlow() throws {
        knock(times: 5)
        #expect(self.pasteboard.lastCopy == nil)
        self.date.offset += 31
        #expect(self.pasteboard.lastCopy == nil)
        knock(times: 1)
        #expect(self.pasteboard.lastCopy == nil)
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

fileprivate final class TestPasteboard: AirshipPasteboardProtocol, @unchecked Sendable {
    var lastCopy: (String, TimeInterval)?

    func copy(value: String) {
        lastCopy = (value, -1)
    }

    func copy(value: String, expiry: TimeInterval) {
        lastCopy = (value, expiry)
    }
}
