/* Copyright Airship and Contributors */

import Foundation

@preconcurrency
import UserNotifications

// NOTE: For internal use only. :nodoc:
final class DefaultAppIntegrationDelegate: NSObject, AppIntegrationDelegate, Sendable {

    let push: any InternalPushProtocol
    let analytics: any InternalAnalyticsProtocol
    let pushableComponents: [any AirshipPushableComponent]

    init(
        push: any InternalPushProtocol,
        analytics: any InternalAnalyticsProtocol,
        pushableComponents: [any AirshipPushableComponent]
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
    
        Task { @MainActor in
            self.push.didRegisterForRemoteNotifications(deviceToken)
            self.analytics.onDeviceRegistration(token: tokenString)
        }
    }

    public func didFailToRegisterForRemoteNotifications(error: any Error) {
        AirshipLogger.error(
            "Application failed to register for remote notifications with error \(error)"
        )
        Task { @MainActor in
            self.push.didFailToRegisterForRemoteNotifications(error)
        }
    }
    
    #if !os(watchOS)
    func didReceiveRemoteNotification(
        userInfo: [AnyHashable : Any],
        isForeground: Bool
    ) async -> UIBackgroundFetchResult {
        guard !isForeground || AirshipUtils.isSilentPush(userInfo) else {
            // will be handled by willPresentNotification(userInfo:presentationOptions:completionHandler:)
            return .noData
        }
        
        let wrapped = try? AirshipJSON.wrap(userInfo)
        
        let result = await self.processPush(
            wrapped?.unwrapAsUserInfo() ?? [:],
            isForeground: isForeground,
            presentationOptions: nil
        )
        
        return UIBackgroundFetchResult(rawValue: result) ?? .noData
    }
    #else
    public func didReceiveRemoteNotification(
        userInfo: [AnyHashable: Any],
        isForeground: Bool
    ) async -> WKBackgroundFetchResult {

        guard !isForeground || AirshipUtils.isSilentPush(userInfo) else {
            // will be handled by willPresentNotification(userInfo:presentationOptions:completionHandler:)
            return .noData
        }
        
        let wrapped = try? AirshipJSON.wrap(userInfo)
        
        let result = await self.processPush(
            wrapped?.unwrapAsUserInfo() ?? [:],
            isForeground: isForeground,
            presentationOptions: nil
        )
        
        return WKBackgroundFetchResult(rawValue: result) ?? .noData
    }
    #endif
    
    func willPresentNotification(
        notification: UNNotification,
        presentationOptions options: UNNotificationPresentationOptions = []
    ) async {
        #if os(tvOS) || os(watchOS)
        return
        #else
        await Task { @MainActor in
            _ = await self.processPush(
                notification.request.content.userInfo,
                isForeground: true,
                presentationOptions: options
            )
        }.value
        #endif
    }

    #if !os(tvOS)
    public func didReceiveNotificationResponse(response: UNNotificationResponse) async {
        AirshipLogger.info(
            "Application received notification response: \(response)"
        )

        let userInfo = response.notification.request.content.userInfo
        let responseText = (response as? UNTextInputNotificationResponse)?.userText
        let categoryID = response.notification.request.content.categoryIdentifier
        let actionID = response.actionIdentifier
        
        let wrappedUserInfo = try? AirshipJSON.wrap(userInfo)
        
        let actionsPayload = self.actionsPayloadForNotification(
            userInfo: unwrapUserInfo(wrappedUserInfo) ?? [:],
            actionID: actionID
        )
        
        // Analytics
        await Task { @MainActor @Sendable in
            let action = await self.notificationAction(
                categoryID: categoryID,
                actionID: actionID
            )
            
            self.analytics.onNotificationResponse(
                response: response,
                action: action
            )

            // Pushable components
            for component in pushableComponents {
                await component.receivedNotificationResponse(response)
            }
        }.value
        
        if let actionsPayload = actionsPayload {
            let action = await self.notificationAction(
                categoryID: categoryID,
                actionID: actionID
            )
            
            let situation = self.situationFromAction(action) ?? .launchedFromPush
            let metadata: [String: any Sendable] = [
                ActionArguments.userNotificationActionIDMetadataKey: actionID,
                ActionArguments.pushPayloadJSONMetadataKey: wrappedUserInfo,
                ActionArguments.responseInfoMetadataKey: responseText
            ]
            
            await ActionRunner.run(
                actionsPayload: actionsPayload,
                situation: situation,
                metadata: metadata
            )
        }

        await Task { @MainActor in
            await self.push.didReceiveNotificationResponse(response)
        }.value
    }
    #endif
    
    private func unwrapUserInfo(_ json: AirshipJSON?) -> [AnyHashable: Any]? {
        guard
            let json, json.isObject,
            let value = json.unWrap(),
            let restored = value as? [AnyHashable: Any]
        else {
            return nil
        }
        
        return restored
    }
    
    public func presentationOptionsForNotification(
        _ notification: UNNotification,
        completionHandler: @Sendable @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @Sendable in
            let options = await self.push.presentationOptionsForNotification(notification)
            completionHandler(options)
        }
    }

    @MainActor
    private func processPush(
        _ userInfo: [AnyHashable: Any],
        isForeground: Bool,
        presentationOptions: UNNotificationPresentationOptions?
    ) async -> UInt {
        
        AirshipLogger.info(
            "Application received remote notification: \(userInfo)"
        )

        let fetchResults = AirshipAtomicValue(Array<UInt>())
        let wrappedUserInfo = safeWrap(userInfo: userInfo) ?? .null

        // Pushable components
        await withTaskGroup(of: UInt.self) { taskGroup in
            for component in pushableComponents {
                taskGroup.addTask {
                    (await component.receivedRemoteNotification(wrappedUserInfo)).rawValue
                }
            }
            
            for await result in taskGroup {
                fetchResults.update(onModify: { $0 + [result] })
            }
        }

        
        let fetchResult = await getFetchResult(userInfo, isForeground: isForeground)
        fetchResults.update(onModify: { $0 + [fetchResult] })

        if let pushJSON = self.safeWrap(userInfo: userInfo) {
            let situation: ActionSituation = isForeground ? .foregroundPush : .backgroundPush
            let isForegroundPresentation = self.isForegroundPresentation(presentationOptions)

            let metadata: [String: any Sendable] = [
                ActionArguments.pushPayloadJSONMetadataKey: pushJSON,
                ActionArguments.isForegroundPresentationMetadataKey: isForegroundPresentation
            ]
            
            await ActionRunner.run(
                actionsPayload: pushJSON,
                situation: situation,
                metadata: metadata
            )
        }

        return AirshipUtils.mergeFetchResults(fetchResults.value).rawValue
    }
    
    @MainActor
    private func getFetchResult(
        _ userInfo: [AnyHashable: Any],
        isForeground: Bool
    ) async -> UInt {
#if !os(watchOS)
        let result = await self.push.didReceiveRemoteNotification(userInfo, isForeground: isForeground) as! UIBackgroundFetchResult
#else
        let result = await self.push.didReceiveRemoteNotification(userInfo, isForeground: isForeground) as! WKBackgroundFetchResult
#endif
        return result.rawValue
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
    private func notificationAction(categoryID: String, actionID: String) async
        -> UNNotificationAction?
    {
        guard actionID != UNNotificationDefaultActionIdentifier else {
            return nil
        }

        var category: UNNotificationCategory?
        #if !os(tvOS)
        category = await self.push.combinedCategories.first(where: {
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

internal extension AirshipJSON {
    func unwrapAsUserInfo() -> [AnyHashable: Any]? {
        return unWrap() as? [AnyHashable: Any]
    }
}
