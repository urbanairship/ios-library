/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
class DefaultAppIntegrationDelegate: NSObject, AppIntegrationDelegate {

    let push: InternalPushProtocol
    let analytics: InternalAnalyticsProtocol
    let pushableComponents: [AirshipPushableComponent]

    init(
        push: InternalPushProtocol,
        analytics: InternalAnalyticsProtocol,
        pushableComponents: [AirshipPushableComponent]
    ) {
        self.push = push
        self.analytics = analytics
        self.pushableComponents = pushableComponents
    }

    public func onBackgroundAppRefresh() {
        AirshipLogger.info("Application received background app refresh")
        self.push.dispatchUpdateAuthorizedNotificationTypes()
    }

    public func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = AirshipUtils.deviceTokenStringFromDeviceToken(deviceToken)

        AirshipLogger.info(
            "Application registered device token: \(tokenString)"
        )
        self.push.didRegisterForRemoteNotifications(deviceToken)
        self.analytics.onDeviceRegistration(token: tokenString)
    }

    public func didFailToRegisterForRemoteNotifications(error: Error) {
        AirshipLogger.error(
            "Application failed to register for remote notifications with error \(error)"
        )
        self.push.didFailToRegisterForRemoteNotifications(error)
    }

    #if !os(watchOS)
    @MainActor
    public func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        isForeground: Bool,
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {

        guard !isForeground || AirshipUtils.isSilentPush(userInfo) else {
            // will be handled by willPresentNotification(userInfo:presentationOptions:completionHandler:)
            completionHandler(.noData)
            return
        }

        self.processPush(
            userInfo,
            isForeground: isForeground,
            presentationOptions: nil
        ) { result in
            completionHandler(
                UIBackgroundFetchResult(rawValue: result) ?? .noData
            )
        }
    }
    #else
    @MainActor
    public func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        isForeground: Bool,
        completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    ) {

        guard !isForeground || AirshipUtils.isSilentPush(userInfo) else {
            // will be handled by willPresentNotification(userInfo:presentationOptions:completionHandler:)
            completionHandler(.noData)
            return
        }

        self.processPush(
            userInfo,
            isForeground: isForeground,
            presentationOptions: nil
        ) { result in
            completionHandler(
                WKBackgroundFetchResult(rawValue: result) ?? .noData
            )
        }
    }
    #endif

    @MainActor
    public func willPresentNotification(
        notification: UNNotification,
        presentationOptions: UNNotificationPresentationOptions,
        completionHandler: @escaping () -> Void
    ) {
        #if os(tvOS) || os(watchOS)
        completionHandler()
        #else
        self.processPush(
            notification.request.content.userInfo,
            isForeground: true,
            presentationOptions: presentationOptions
        ) { _ in
            completionHandler()
        }
        #endif
    }

    #if !os(tvOS)
    @MainActor
    public func didReceiveNotificationResponse(
        response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) {
        AirshipLogger.info(
            "Application received notification response: \(response)"
        )

        let dispatchGroup = DispatchGroup()
        let userInfo = response.notification.request.content.userInfo
        let responseText = (response as? UNTextInputNotificationResponse)?.userText
        let categoryID = response.notification.request.content.categoryIdentifier
        let actionID = response.actionIdentifier
        let action = self.notificationAction(
            categoryID: categoryID,
            actionID: actionID
        )
        let actionsPayload = self.actionsPayloadForNotification(
            userInfo: userInfo,
            actionID: actionID
        )

        // Analytics
        self.analytics.onNotificationResponse(
            response: response,
            action: action
        )

        // Pushable components
        self.pushableComponents.forEach {
            dispatchGroup.enter()
            $0.receivedNotificationResponse(response) {
                dispatchGroup.leave()
            }
        }

        if let actionsPayload = actionsPayload {
            dispatchGroup.enter()
            Task {
                let pushPayloadJSON = try? AirshipJSON.wrap(userInfo)
                let situation = self.situationFromAction(action) ?? .launchedFromPush
                let metadata: [String: Sendable] = [
                    ActionArguments.userNotificationActionIDMetadataKey: actionID,
                    ActionArguments.pushPayloadJSONMetadataKey: pushPayloadJSON,
                    ActionArguments.responseInfoMetadataKey: responseText
                ]
                await ActionRunner.run(
                    actionsPayload: actionsPayload,
                    situation: situation,
                    metadata: metadata
                )
                dispatchGroup.leave()
            }
        }


        dispatchGroup.enter()
        self.push.didReceiveNotificationResponse(response) {
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            completionHandler()
        }
    }
    #endif
    
    public func presentationOptionsForNotification(
        _ notification: UNNotification,
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        self.push.presentationOptionsForNotification(notification) { presentationOptions in
            completionHandler(presentationOptions)
        }
    }

    @MainActor
    private func processPush(
        _ userInfo: [AnyHashable: Any],
        isForeground: Bool,
        presentationOptions: UNNotificationPresentationOptions?,
        completionHandler: @escaping (UInt) -> Void
    ) {
        
        AirshipLogger.info(
            "Application received remote notification: \(userInfo)"
        )

        let dispatchGroup = DispatchGroup()
        var fetchResults: [UInt] = []
        let lock = AirshipLock()

        // Pushable components
        self.pushableComponents.forEach {
            dispatchGroup.enter()
            $0.receivedRemoteNotification(userInfo) { fetchResult in
                lock.sync {
                    fetchResults.append(fetchResult.rawValue)
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.enter()
        self.push.didReceiveRemoteNotification(
            userInfo,
            isForeground: isForeground
        ) { pushResult in
            lock.sync {
#if !os(watchOS)
                let result: UIBackgroundFetchResult =
                pushResult as! UIBackgroundFetchResult
#else
                let result: WKBackgroundFetchResult =
                pushResult as! WKBackgroundFetchResult

#endif
                fetchResults.append(result.rawValue)
            }
            dispatchGroup.leave()
        }


        if let pushJSON = self.safeWrap(userInfo: userInfo) {
            let situation: ActionSituation = isForeground ? .foregroundPush : .backgroundPush
            let isForegroundPresentation = self.isForegroundPresentation(presentationOptions)

            let metadata: [String: Sendable] = [
                ActionArguments.pushPayloadJSONMetadataKey: pushJSON,
                ActionArguments.isForegroundPresentationMetadataKey: isForegroundPresentation
            ]
            dispatchGroup.enter()
            Task {
                await ActionRunner.run(
                    actionsPayload: pushJSON,
                    situation: situation,
                    metadata: metadata
                )
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completionHandler(AirshipUtils.mergeFetchResults(fetchResults).rawValue)
        }
    }

    @available(tvOS, unavailable)
    private func situationFromAction(
        _ action: UNNotificationAction?
    ) -> ActionSituation? {
        if let options = action?.options {
            guard options.contains(.foreground) else {
                return .backgroundInteractiveButton
            }
            return .foregroundInteractiveButton
        }
        return nil
    }

    private func isForegroundPresentation(
        _ presentationOptions: UNNotificationPresentationOptions?
    ) -> Bool {

        guard var presentationOptions = presentationOptions else {
            return false
        }

        // Remove all the non-alerting options in the foreground
        presentationOptions.remove(.sound)
        presentationOptions.remove(.badge)

        // Make sure its still not empty
        return presentationOptions != []
    }

    @available(tvOS, unavailable)
    private func actionsPayloadForNotification(
        userInfo: [AnyHashable: Any],
        actionID: String?
    ) -> AirshipJSON? {
        guard let actionID = actionID,
            actionID != UNNotificationDefaultActionIdentifier
        else {
            return try? AirshipJSON.wrap(userInfo)
        }

        let interactive = userInfo["com.urbanairship.interactive_actions"] as? [AnyHashable: Any]
        let actions = interactive?[actionID]

        return try? AirshipJSON.wrap(actions)
    }

    @available(tvOS, unavailable)
    private func notificationAction(categoryID: String, actionID: String)
        -> UNNotificationAction?
    {
        guard actionID != UNNotificationDefaultActionIdentifier else {
            return nil
        }

        var category: UNNotificationCategory?
        #if !os(tvOS)
        category = self.push.combinedCategories.first(where: {
            return $0.identifier == categoryID
        })
        #endif
        if category == nil {
            AirshipLogger.error(
                "Unknown notification category identifier \(categoryID)"
            )
            return nil
        }

        let action = category?.actions
            .first(where: {
                return $0.identifier == actionID
            })
        if action == nil {
            AirshipLogger.error(
                "Unknown notification action identifier \(actionID)"
            )
            return nil
        }

        return action
    }


    private func safeWrap(userInfo: [AnyHashable: Any]?) -> AirshipJSON? {
        guard let userInfo = userInfo else {
            return nil
        }

        if let json = try? AirshipJSON.wrap(userInfo) {
            return json
        }

        var parsed: [String: AirshipJSON] = [:]

        userInfo.forEach { (key, value) in
            if let stringKey = key as? String,
               let jsonValue = try? AirshipJSON.wrap(value) {
                parsed[stringKey] = jsonValue
            } else {
                AirshipLogger.debug("Unexpected key value in push payload: \(key) \(value)")
            }
            
        }

        return try? AirshipJSON.wrap(parsed)
    }
}
