/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

typealias MessageConvertor = @Sendable (LegacyInAppMessage) -> AutomationSchedule?
typealias MessageExtender = @Sendable (InAppMessage) -> InAppMessage
typealias ScheduleExtender = @Sendable (AutomationSchedule) -> AutomationSchedule

final class LegacyInAppMessaging: NSObject, @unchecked Sendable {
    
    private let dataStore: PreferenceDataStore
    private let disableHelper: ComponentDisableHelper
    private let analytics: InAppMessageAnalyticsProtocol
    private let automationEngine: AutomationEngineProtocol
    
    @MainActor var customMessageConverter: MessageConvertor?
    @MainActor var messageExtender: MessageExtender?
    @MainActor var scheduleExtender: ScheduleExtender?
    
    private let date: AirshipDateProtocol
    
    init(
        analytics: InAppMessageAnalyticsProtocol,
        dataStore: PreferenceDataStore,
        automationEngine: AutomationEngineProtocol,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.disableHelper = ComponentDisableHelper(dataStore: dataStore, className: "UALegacyInAppMessaging")
        self.analytics = analytics
        self.automationEngine = automationEngine
        self.dataStore = dataStore
        self.date = date
        
        super.init()
        
        cleanUpOldData()
    }
    
    var isComponentEnabled: Bool {
        get { return disableHelper.enabled }
        set { disableHelper.enabled = newValue }
    }
    
    var pendingMessageId: String? {
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
        
        if let pending = self.pendingMessageId {
            do {
                try await self.automationEngine.cancelSchedule(identifier: pending)
            } catch {
                AirshipLogger.debug("LegacyInAppMessageManager: failed to cancel \(pending), \(error)")
            }
            //TODO: uncomment once analytics is ready
//                UA_LDEBUG(@"LegacyInAppMessageManager - Pending in-app message replaced");
//                UAInAppReporting *reporting = [UAInAppReporting legacyReplacedEventWithScheduleID:previousMessageID
//                                                                                   replacementID:schedule.identifier];
//
//                [reporting record:self.analytics];
        }
        
        self.pendingMessageId = schedule.identifier
        
        do {
            try await self.automationEngine.schedule([schedule])
            AirshipLogger.debug("LegacyInAppMessageManager - schedule is saved \(schedule)")
        } catch {
            AirshipLogger.error("Failed to schedule \(schedule)")
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
                    label: InAppMessageTextInfo(text: action.title, color: primaryColor, alignment: .center),
                    actions: message.buttonActions?[action.identifier],
                    backgroundColor: secondaryColor,
                    borderRadius: Defaults.borderRadius)
            })
        
        let displayContent = InAppMessageDisplayContent.Banner(
            body: InAppMessageTextInfo(text: message.alert, color: secondaryColor),
            buttons: buttons,
            buttonLayoutType: .seperate,
            backgroundColor: primaryColor,
            dismissButtonColor: secondaryColor,
            borderRadius: Defaults.borderRadius,
            duration: message.duration,
            placement: message.position.bannerPlacement,
            actions: message.onClick
        )
        
        let inAppMessage = InAppMessage(
            name: message.alert,
            displayContent: .banner(displayContent),
            source: .legacyPush,
            extras: message.extra
        )
        
        let finalMessage = self.messageExtender?(inAppMessage) ?? inAppMessage
        
        // In terms of the scheduled message model, displayASAP means using an active session trigger.
        // Otherwise the closest analog to the v1 behavior is the foreground trigger.
        let trigger = self.displayASAPEnabled ?
            AutomationTrigger.activeSession(count: 1) :
            AutomationTrigger.foreground(count: 1)
        
        let schedule = AutomationSchedule(
            identifier: message.identifier,
            data: .inAppMessage(finalMessage),
            triggers: [trigger],
            created: date.now,
            lastUpdated: date.now,
            end: message.expiry,
            campaigns: message.campaigns,
            messageType: message.messageType
        )
        
        return self.scheduleExtender?(schedule) ?? schedule
    }
}

extension LegacyInAppMessaging: PushableComponent {
    
    func receivedNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        guard
            userInfo.keys.contains(Keys.incomingMessageKey.rawValue),
            let messageId = userInfo["_"] as? String,
            messageId == self.pendingMessageId
        else {
            completionHandler()
            return
        }
        
        Task {
            do {
                try await self.automationEngine.cancelSchedule(identifier: messageId)
            } catch {
                AirshipLogger.debug("LegacyInAppMessageManager: failed to cancel \(messageId), \(error)")
            }
            //TODO: implement once in app reporting is migrated
//            UAInAppReporting *reporting = [UAInAppReporting legacyDirectOpenEventWithScheduleID:pendingMessageID];
//            [reporting record:self.analytics];
        }
        
        self.pendingMessageId = nil
        completionHandler()
        
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
        } else {
            messageCenterAction = nil
        }
        
        if let message = LegacyInAppMessage(payload: payload, overrideId: overrideId, overrideOnClick: messageCenterAction) {
            Task {
                await schedule(message: message)
            }
        }
        
        completionHandler(.noData)
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
