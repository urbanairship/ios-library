/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

public typealias MessageConvertor = @Sendable (LegacyInAppMessage) -> AutomationSchedule?
public typealias MessageExtender = @Sendable (inout InAppMessage) -> Void
public typealias ScheduleExtender = @Sendable (inout AutomationSchedule) -> Void

/// Legacy in-app messaging protocol 
public protocol LegacyInAppMessagingProtocol: AnyObject, Sendable {
    /// Optional message converter from a `LegacyInAppMessage` to an `AutomationSchedule`
    @MainActor
    var customMessageConverter: MessageConvertor? { get set }

    /// Optional message extender.
    @MainActor
    var messageExtender: MessageExtender?  { get set }

    /// Optional schedule extender.
    @MainActor
    var scheduleExtender: ScheduleExtender?  { get set }

    /// Sets whether legacy messages will display immediately upon arrival, instead of waiting
    /// until the following foreground. Defaults to `true`.
    @MainActor
    var displayASAPEnabled: Bool  { get set }
}

protocol InternalLegacyInAppMessagingProtocol: LegacyInAppMessagingProtocol {
    func receivedNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void)

    func receivedRemoteNotification(_ notification: [AnyHashable : Any],
                                    completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

final class LegacyInAppMessaging: LegacyInAppMessagingProtocol, @unchecked Sendable {

    private let dataStore: PreferenceDataStore
    private let analytics: LegacyInAppAnalyticsProtocol
    private let automationEngine: AutomationEngineProtocol
    
    @MainActor 
    public var customMessageConverter: MessageConvertor?

    @MainActor
    public var messageExtender: MessageExtender?

    @MainActor
    public var scheduleExtender: ScheduleExtender?

    private let date: AirshipDateProtocol
    
    init(
        analytics: LegacyInAppAnalyticsProtocol,
        dataStore: PreferenceDataStore,
        automationEngine: AutomationEngineProtocol,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.analytics = analytics
        self.automationEngine = automationEngine
        self.dataStore = dataStore
        self.date = date

        cleanUpOldData()
    }

    var pendingMessageID: String? {
        get {
            return dataStore.string(forKey: Keys.CurrentStorage.pendingMessageIds.rawValue)
        }
        set {
            dataStore.setObject(newValue, forKey: Keys.CurrentStorage.pendingMessageIds.rawValue)
        }
    }
    
    /**
     * Sets whether legacy messages will display immediately upon arrival, instead of waiting
     * until the following foreground. Defaults to `YES`.
     */
    @MainActor
    var displayASAPEnabled: Bool = true
    
    private func cleanUpOldData() {
        self.dataStore.removeObject(forKey: Keys.LegacyStorage.pendingMessages.rawValue)
        self.dataStore.removeObject(forKey: Keys.LegacyStorage.autoDisplayMessage.rawValue)
        self.dataStore.removeObject(forKey: Keys.LegacyStorage.lastDisplayedMessageId.rawValue)
    }
    
    private func schedule(message: LegacyInAppMessage) async {
        let generator = await customMessageConverter ?? generateScheduleFor
        
        guard let schedule = await generator(message) else {
            AirshipLogger.error("Failed to convert legacy in-app automation: \(message)")
            return
        }
        
        if let pending = self.pendingMessageID {
            if await self.scheduleExists(identifier: pending) {
                AirshipLogger.debug("Pending in-app message replaced")
                self.analytics.recordReplacedEvent(
                    scheduleID: pending,
                    replacementID: schedule.identifier
                )
            }

            await self.cancelSchedule(identifier: pending)
        }
        
        self.pendingMessageID = schedule.identifier

        do {
            try await self.automationEngine.upsertSchedules([schedule])
            AirshipLogger.debug("LegacyInAppMessageManager - schedule is saved \(schedule)")
        } catch {
            AirshipLogger.error("Failed to schedule \(schedule)")
        }
    }

    private func scheduleExists(identifier: String) async -> Bool {
        do {
            return try await automationEngine.getSchedule(identifier: identifier) != nil
        } catch {
            AirshipLogger.debug("Failed to query schedule \(identifier), \(error)")
            return true
        }
    }

    private func cancelSchedule(identifier: String) async {
        do {
            return try await automationEngine.cancelSchedules(identifiers: [identifier])
        } catch {
            AirshipLogger.debug("Failed to cancel schedule \(identifier), \(error)")
        }
    }

    @MainActor
    private func generateScheduleFor(message: LegacyInAppMessage) -> AutomationSchedule? {
        let primaryColor = InAppMessageColor(hexColorString: message.primaryColor ?? Defaults.primaryColor)
        let secondaryColor = InAppMessageColor(hexColorString: message.secondaryColor ?? Defaults.secondaryColor)
        
        let buttons = message
            .notificationActions?
            .prefix(Defaults.notificationButtonsCount)
            .map({ action in
                return InAppMessageButtonInfo(
                    identifier: action.identifier,
                    label: InAppMessageTextInfo(
                        text: action.title,
                        color: primaryColor,
                        alignment: .left
                    ),
                    actions: message.buttonActions?[action.identifier],
                    backgroundColor: secondaryColor,
                    borderRadius: Defaults.borderRadius
                )
            })
        
        let displayContent = InAppMessageDisplayContent.Banner(
            body: InAppMessageTextInfo(text: message.alert, color: secondaryColor),
            buttons: buttons,
            buttonLayoutType: .separate,
            backgroundColor: primaryColor,
            dismissButtonColor: secondaryColor,
            borderRadius: Defaults.borderRadius,
            duration: message.duration,
            placement: message.position.bannerPlacement,
            actions: message.onClick
        )
        
        var inAppMessage = InAppMessage(
            name: message.alert,
            displayContent: .banner(displayContent),
            source: .legacyPush,
            extras: message.extra
        )
        
        self.messageExtender?(&inAppMessage)

        // In terms of the scheduled message model, displayASAP means using an active session trigger.
        // Otherwise the closest analog to the v1 behavior is the foreground trigger.
        let trigger = self.displayASAPEnabled ?
            AutomationTrigger.activeSession(count: 1) :
            AutomationTrigger.foreground(count: 1)
        
        var schedule = AutomationSchedule(
            identifier: message.identifier,
            data: .inAppMessage(inAppMessage),
            triggers: [trigger],
            created: date.now,
            lastUpdated: date.now,
            end: message.expiry,
            campaigns: message.campaigns,
            messageType: message.messageType
        )
        self.scheduleExtender?(&schedule)
        return schedule
    }
}

extension LegacyInAppMessaging: InternalLegacyInAppMessagingProtocol {

    func receivedNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        guard
            userInfo.keys.contains(Keys.incomingMessageKey.rawValue),
            let messageID = userInfo["_"] as? String,
            messageID == self.pendingMessageID
        else {
            completionHandler()
            return
        }
        
        self.pendingMessageID = nil

        Task {
            if await self.scheduleExists(identifier: messageID) {
                AirshipLogger.debug("Pending in-app message replaced")
                self.analytics.recordDirectOpenEvent(scheduleID: messageID)
            }

            await self.cancelSchedule(identifier: messageID)
            completionHandler()
        }
    }
    
    func receivedRemoteNotification(_ notification: [AnyHashable : Any], 
                                    completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let payload = notification[Keys.incomingMessageKey.rawValue] as? [String: Any] else {
            completionHandler(.noData)
            return
        }
        
        let overrideId = notification["_"] as? String
        let messageCenterAction: AirshipJSON?

        if
            let actionRaw = notification[Keys.messageCenterActionKey.rawValue] as? [String: Any],
            let action = try? AirshipJSON.wrap(actionRaw) {
            messageCenterAction = action
        } else if let messageId = notification[Keys.messageCenterActionKey.rawValue] as? String {
            messageCenterAction = .object([Keys.messageCenterActionKey.rawValue: .string(messageId)])
        } else {
            messageCenterAction = nil
        }

        let message = LegacyInAppMessage(
            payload: payload,
            overrideId: overrideId,
            overrideOnClick: messageCenterAction,
            date: self.date
        )
        
        if let message = message {
            Task {
                await schedule(message: message)
                completionHandler(.noData)
            }
        } else {
            completionHandler(.noData)
        }
    }
    
    private enum Keys: String {
        enum LegacyStorage: String {
            // User defaults key for storing and retrieving pending messages
            case pendingMessages = "UAPendingInAppMessage"
            
            // User defaults key for storing and retrieving auto display enabled
            case autoDisplayMessage = "UAAutoDisplayInAppMessageDataStoreKey"
            
            // Legacy key for the last displayed message ID
            case lastDisplayedMessageId = "UALastDisplayedInAppMessageID"
        }
        
        enum CurrentStorage: String {
            // Data store key for storing and retrieving pending message IDs
            case pendingMessageIds = "UAPendingInAppMessageID"
        }
        
        case incomingMessageKey = "com.urbanairship.in_app"
        case messageCenterActionKey = "_uamid"
    }
    
    private enum Defaults {
        static let primaryColor = "#FFFFFF"
        static let secondaryColor = "#1C1C1C"
        static let borderRadius = 2.0
        static let notificationButtonsCount = 2
    }
}

fileprivate extension LegacyInAppMessage.Position {
    var bannerPlacement: InAppMessageDisplayContent.Banner.Placement {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
}
