/* Copyright Airship and Contributors */

import Foundation

/**
 * Channel Capture copies the channelId to the device clipboard after a specific number of
 * knocks (app foregrounds) within a specific timeframe. Channel Capture can be enabled
 * or disabled in Airship Config.
 */
@available(tvOS, unavailable)
@objc(UAChannelCapture)
public class ChannelCapture : NSObject {
    private static let knocksToTriggerChannelCapture = 6
    private static let knocksMaxTimeSeconds : TimeInterval = 30
    private static let pasteboardExpirationSeconds: TimeInterval = 60
    
    private let dataStore: UAPreferenceDataStore
    private let config: RuntimeConfig
    private let channel: ChannelProtocol
    private let notificationCenter: NotificationCenter
    private let date: UADate
    private let pasteboardProvider: () -> UIPasteboard
    
    private var knockTimes: [Date] = []
    
    /**
     * Flag indicating whether channel capture is enabled. Clear to disable. Set to enable.
     * Note: Does not persist through app launches.
     */
    @objc
    public var enabled: Bool = false
    
    @objc
    public init(config: RuntimeConfig,
                dataStore: UAPreferenceDataStore,
                channel: ChannelProtocol,
                notificationCenter: NotificationCenter,
                date: UADate,
                pasteboardProvider: @escaping () -> UIPasteboard) {
        
        self.config = config
        self.dataStore = dataStore
        self.channel = channel
        self.notificationCenter = notificationCenter
        self.date = date
        self.pasteboardProvider = pasteboardProvider
        
        self.enabled = config.isChannelCaptureEnabled
        
        super.init()
        
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidTransitionToForeground),
                                       name: UAAppStateTracker.didTransitionToForeground,
                                       object: nil)
    }
    
    @objc
    public convenience init(config: RuntimeConfig,
                            dataStore: UAPreferenceDataStore,
                            channel: Channel) {
        
        self.init(config: config,
                  dataStore: dataStore,
                  channel: channel,
                  notificationCenter: NotificationCenter.default,
                  date: UADate(),
                  pasteboardProvider: { UIPasteboard.general })
    }
    
    @objc
    private func applicationDidTransitionToForeground() {
        guard enabled else {
            return
        }
        
        // Save time of transition
        if knockTimes.count >= ChannelCapture.knocksToTriggerChannelCapture {
            knockTimes.remove(at: 0)
        }
        knockTimes.append(date.now)
        
        if knockTimes.count < ChannelCapture.knocksToTriggerChannelCapture {
            return
        }
        
        let firstKnock = knockTimes[0]
        let lastKnock = knockTimes[ChannelCapture.knocksToTriggerChannelCapture - 1]
        if (lastKnock.timeIntervalSince(firstKnock) > ChannelCapture.knocksMaxTimeSeconds) {
            return
        }
        
        knockTimes.removeAll()
        
        if channel.identifier == nil {
            AirshipLogger.debug("The channel ID does not exist.")
        }
        
        let identifier = "ua:\(channel.identifier ?? "")"
        let expirationDate = date.now.addingTimeInterval(ChannelCapture.pasteboardExpirationSeconds)
        
        AirshipLogger.debug("Setting pasteboard with channel identifier = \(identifier)")
        pasteboardProvider().setItems([[UIPasteboard.typeAutomatic: identifier]],
                                      options: [UIPasteboard.OptionsKey.expirationDate: expirationDate])
    }
}
