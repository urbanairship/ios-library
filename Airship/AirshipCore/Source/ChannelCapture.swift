/* Copyright Airship and Contributors */

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if !os(watchOS)

/// Channel Capture copies the channelId to the device clipboard after a specific number of
/// knocks (app foregrounds) within a specific timeframe. Channel Capture can be enabled
/// or disabled in Airship Config.
@available(tvOS, unavailable)
final public class ChannelCapture: Sendable {
    private static let knocksToTriggerChannelCapture = 6
    private static let knocksMaxTimeSeconds: TimeInterval = 30
    private static let pasteboardExpirationSeconds: TimeInterval = 60

    private let config: RuntimeConfig
    private let channel: any AirshipChannelProtocol
    private let notificationCenter: NotificationCenter
    private let date: any AirshipDateProtocol
    private let pasteboard: any AirshipPasteboardProtocol

    @MainActor
    private var knockTimes: [Date] = []

    /**
     * Flag indicating whether channel capture is enabled. Clear to disable. Set to enable.
     * Note: Does not persist through app launches.
     */
    @MainActor
    public var enabled: Bool {
        didSet {
            AirshipLogger.trace("Channel capture enabled: \(enabled)")
        }
    }

    init(
        config: RuntimeConfig,
        channel: any AirshipChannelProtocol,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        date: any AirshipDateProtocol = AirshipDate.shared,
        pasteboard: any AirshipPasteboardProtocol = UIPasteboard.general
    ) {
        self.config = config
        self.channel = channel
        self.notificationCenter = notificationCenter
        self.date = date
        self.pasteboard = pasteboard

        self.enabled = config.airshipConfig.isChannelCaptureEnabled

        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTransitionToForeground),
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )
    }

    @objc
    @MainActor
    private func applicationDidTransitionToForeground() {
        guard enabled else {
            AirshipLogger.trace(
                "Channel Capture disabled, ignoring foreground."
            )
            return
        }

        // Save time of transition
        if knockTimes.count >= ChannelCapture.knocksToTriggerChannelCapture {
            knockTimes.remove(at: 0)
        }

        AirshipLogger.trace(
            "Channel Capture capturing foreground at time \(date.now)"
        )
        knockTimes.append(date.now)

        if knockTimes.count < ChannelCapture.knocksToTriggerChannelCapture {
            return
        }

        let firstKnock = knockTimes[0]
        let lastKnock = knockTimes[
            ChannelCapture.knocksToTriggerChannelCapture - 1
        ]
        if lastKnock.timeIntervalSince(firstKnock)
            > ChannelCapture.knocksMaxTimeSeconds
        {
            return
        }

        knockTimes.removeAll()

        let identifier = "ua:\(channel.identifier ?? "")"
        AirshipLogger.debug(
            "Channel Capture setting channel ID:\(identifier) to pasteboard."
        )

        self.pasteboard.copy(
            value: identifier,
            expiry: ChannelCapture.pasteboardExpirationSeconds
        )
    }
}

@available(tvOS, unavailable)
protocol AirshipPasteboardProtocol: Sendable {
    func copy(value: String, expiry: TimeInterval)
}

@available(tvOS, unavailable)
extension UIPasteboard: AirshipPasteboardProtocol {

    func copy(value: String, expiry: TimeInterval) {
        let expirationDate = Date().advanced(by: expiry)
        self.setItems(
            [[UIPasteboard.typeAutomatic: value]],
            options: [
                UIPasteboard.OptionsKey.expirationDate: expirationDate
            ]
        )
    }
}

#endif


