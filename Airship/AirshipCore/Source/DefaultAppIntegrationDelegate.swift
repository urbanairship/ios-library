/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
class DefaultAppIntegrationDelegate : NSObject, AppIntegrationDelegate {
    
    let push: InternalPushProtocol
    let analytics: InternalAnalyticsProtocol
    let pushableComponents: [PushableComponent]
    
    init(push: InternalPushProtocol, analytics: InternalAnalyticsProtocol, pushableComponents: [PushableComponent]) {
        self.push = push
        self.analytics = analytics
        self.pushableComponents = pushableComponents
    }
    
    @objc
    public override convenience init() {
        self.init(push: Airship.push,
                  analytics: Airship.analytics,
                  pushableComponents: Airship.shared.components.compactMap { return $0 as? PushableComponent })
    }
    
    public func onBackgroundAppRefresh() {
        AirshipLogger.info("Application received backgound app refresh")
        self.push.updateAuthorizedNotificationTypes()
    }
    
    public func didRegisterForRemoteNotifications(deviceToken: Data) {
        AirshipLogger.info("Application registered device token: \(deviceToken)")
        self.push.didRegisterForRemoteNotifications(deviceToken)
        self.analytics.onDeviceRegistration()
    }

    public func didFailToRegisterForRemoteNotifications(error: Error) {
        AirshipLogger.error("Application failed to register for remote notifications with error \(error)")
        self.push.didFailToRegisterForRemoteNotifications(error)
    }
    
    #if !os(watchOS)
    public func didReceiveRemoteNotification(userInfo: [AnyHashable: Any],
                                             isForeground: Bool,
                                             completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        guard !isForeground || Utils.isSilentPush(userInfo) else {
            // will be handled by willPresentNotification(userInfo:presentationOptions:completionHandler:)
            completionHandler(.noData)
            return
        }
        
        self.processPush(userInfo,
                         isForeground: isForeground,
                         presentationOptions: nil,
                         completionHandler: completionHandler)
    }
    #else
    public func didReceiveRemoteNotification(userInfo: [AnyHashable: Any],
                                             isForeground: Bool,
                                             completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        
        guard !isForeground || Utils.isSilentPush(userInfo) else {
            // will be handled by willPresentNotification(userInfo:presentationOptions:completionHandler:)
            completionHandler(.noData)
            return
        }
        
        self.processPush(userInfo,
                         isForeground: isForeground,
                         presentationOptions: nil,
                         completionHandler: completionHandler)
    }
    #endif
    
    public func willPresentNotification(notification: UNNotification,
                                        presentationOptions: UNNotificationPresentationOptions,
                                        completionHandler: @escaping () -> Void) {
        #if os(tvOS) || os(watchOS)
        completionHandler()
        #else
        self.processPush(notification.request.content.userInfo, isForeground: true, presentationOptions: presentationOptions) { _ in
            completionHandler()
        }
        #endif
    }
    
    #if !os(tvOS)
    public func didReceiveNotificationResponse(response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        AirshipLogger.info("Application received notification response: \(response)");

        let dispatchGroup = DispatchGroup()
        let userInfo = response.notification.request.content.userInfo
        let responseText = (response as? UNTextInputNotificationResponse)?.userText
        let categoryID = response.notification.request.content.categoryIdentifier
        let actionID = response.actionIdentifier
        let action = self.notificationAction(categoryID: categoryID, actionID: actionID)
        let actionsPayload = self.actionsPayloadForNotification(userInfo: userInfo, actionID: actionID)
        let situation = self.situationFromAction(action) ?? .launchedFromPush
        
        var metadata: [AnyHashable : Any] = [:]
        metadata[UAActionMetadataUserNotificationActionIDKey] = actionID
        metadata[UAActionMetadataPushPayloadKey] = userInfo
        metadata[UAActionMetadataResponseInfoKey] = responseText
        
        // Analytics
        self.analytics.onNotificationResponse(response: response, action: action)

        // Pushable components
        self.pushableComponents.forEach {
            if ($0.receivedNotificationResponse != nil) {
                dispatchGroup.enter()
                $0.receivedNotificationResponse?(response) {
                    dispatchGroup.leave()
                }
            }
        }
        
        // Actions -> Push
        dispatchGroup.enter()
        ActionRunner.run(actionValues: actionsPayload, situation: situation, metadata: metadata) { _ in            
            self.push.didReceiveNotificationResponse(response) {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completionHandler()
        }
    }
    #endif
    
    public func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions {
        var options = self.push.presentationOptionsForNotification(notification)
        
        self.pushableComponents.forEach {
            if let componentOptions = $0.presentationOptions?(for: notification, defaultPresentationOptions: options) {
                options = componentOptions
            }
        }
        
        return options
    }
    
#if !os(watchOS)
    private func processPush(_ userInfo: [AnyHashable: Any],
                             isForeground: Bool,
                             presentationOptions: UNNotificationPresentationOptions?,
                             completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        AirshipLogger.info("Application received remote notification: \(userInfo)");
        
        let situation = isForeground ? Situation.foregroundPush : Situation.backgroundPush
        let dispatchGroup = DispatchGroup()
        var fetchResults: [UInt] = []
        let lock = Lock()
        var metadata: [AnyHashable : Any] = [:]
        metadata[UAActionMetadataPushPayloadKey] = userInfo
        
        if let presentationOptions = presentationOptions {
            metadata[UAActionMetadataForegroundPresentationKey] = self.isForegroundPresentation(presentationOptions)
        }
        
        // Pushable components
        self.pushableComponents.forEach {
            if ($0.receivedRemoteNotification != nil) {
                dispatchGroup.enter()
                $0.receivedRemoteNotification?(userInfo) { fetchResult in
                    lock.sync {
                        fetchResults.append(fetchResult.rawValue)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        // Actions -> Push
        dispatchGroup.enter()
        ActionRunner.run(actionValues: userInfo, situation: situation, metadata: metadata) { result in
            lock.sync {
                fetchResults.append(UInt(result.fetchResult.rawValue))
            }
            self.push.didReceiveRemoteNotification(userInfo, isForeground:isForeground) { pushResult in
                lock.sync {
                    let result: UIBackgroundFetchResult = pushResult as! UIBackgroundFetchResult
                    fetchResults.append(result.rawValue)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completionHandler(Utils.mergeFetchResults(fetchResults))
        }
    }

#else
    private func processPush(_ userInfo: [AnyHashable: Any],
                             isForeground: Bool,
                             presentationOptions: UNNotificationPresentationOptions?,
                             completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        AirshipLogger.info("Application received remote notification: \(userInfo)");
        
        let situation = isForeground ? Situation.foregroundPush : Situation.backgroundPush
        let dispatchGroup = DispatchGroup()
        var fetchResults: [UInt] = []
        let lock = Lock()
        var metadata: [AnyHashable : Any] = [:]
        metadata[UAActionMetadataPushPayloadKey] = userInfo
        
        if let presentationOptions = presentationOptions {
            metadata[UAActionMetadataForegroundPresentationKey] = self.isForegroundPresentation(presentationOptions)
        }
        
        // Pushable components
        self.pushableComponents.forEach {
            if ($0.receivedRemoteNotification != nil) {
                dispatchGroup.enter()
                $0.receivedRemoteNotification?(userInfo) { fetchResult in
                    lock.sync {
                        fetchResults.append(fetchResult.rawValue)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        // Actions -> Push
        dispatchGroup.enter()
        ActionRunner.run(actionValues: userInfo, situation: situation, metadata: metadata) { result in
            lock.sync {
                fetchResults.append(UInt(result.fetchResult.rawValue))
            }
            self.push.didReceiveRemoteNotification(userInfo, isForeground:isForeground) { pushResult in
                lock.sync {
                    let result: WKBackgroundFetchResult = pushResult as! WKBackgroundFetchResult
                    fetchResults.append(result.rawValue)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completionHandler(Utils.mergeFetchResults(fetchResults))
        }
    }
#endif
    
    @available(tvOS, unavailable)
    private func situationFromAction(_ action: UNNotificationAction?) -> Situation? {
        if let options = action?.options {
            if (options.contains(.foreground)) {
                return .foregroundInteractiveButton
            } else {
                return .backgroundInteractiveButton
            }
        }
        return nil
    }
    
    private func isForegroundPresentation(_ presentationOptions: UNNotificationPresentationOptions?) -> Bool {
        var foregroundPresentation = false
        if let presentationOptions = presentationOptions {
            foregroundPresentation = presentationOptions.contains(.alert)
            #if !targetEnvironment(macCatalyst)
            if #available(iOS 14, tvOS 14, *) {
                foregroundPresentation = presentationOptions.contains(.alert) || presentationOptions.contains(.list) || presentationOptions.contains(.banner)
            }
            #endif
        }
        
        return foregroundPresentation
    }
    
    @available(tvOS, unavailable)
    private func actionsPayloadForNotification(userInfo: [AnyHashable : Any], actionID: String?) -> [AnyHashable : Any] {
        guard let actionID = actionID, actionID != UNNotificationDefaultActionIdentifier else {
            return userInfo
        }
        let actions = userInfo["com.urbanairship.interactive_actions"] as? [AnyHashable : Any]
        return actions?[actionID] as? [AnyHashable : Any] ?? [:]
    }
    
    @available(tvOS, unavailable)
    private func notificationAction(categoryID: String, actionID: String) -> UNNotificationAction? {
        var category: UNNotificationCategory?
        #if !os(tvOS)
        category = self.push.combinedCategories.first(where: { return $0.identifier == categoryID})
        #endif
        if (category == nil) {
            AirshipLogger.error("Unknown notification category identifier \(categoryID)")
            return nil
        }
        
        let action = category?.actions.first(where: { return $0.identifier == actionID})
        if (action == nil) {
            AirshipLogger.error("Unknown notification action identifier \(actionID)")
            return nil
        }
        
        return action
    }
}
