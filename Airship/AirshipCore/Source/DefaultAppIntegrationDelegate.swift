/* Copyright Airship and Contributors */

import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(AirshipBasement)
import AirshipBasement
#endif

// NOTE: For internal use only. :nodoc:
final class DefaultAppIntegrationDelegate: AppIntegrationDelegate, Sendable {

    let push: any InternalAirshipPush
    let analytics: any InternalAirshipAnalytics
    let pushableComponents: [any AirshipPushableComponent]

    init(
        push: any InternalAirshipPush,
        analytics: any InternalAirshipAnalytics,
        pushableComponents: [any AirshipPushableComponent]
    ) {
        self.push = push
        self.analytics = analytics
        self.pushableComponents = pushableComponents
    }

    @MainActor
    public func onBackgroundAppRefresh() {
        AirshipLogger.info("Application received background app refresh")
        self.push.dispatchUpdateAuthorizedNotificationTypes()
    }

    @MainActor
    public func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = AirshipUtils.deviceTokenStringFromDeviceToken(deviceToken)
        AirshipLogger.info("Application registered device token: \(tokenString)")
        self.push.didRegisterForRemoteNotifications(deviceToken)
    }

    @MainActor
    public func didFailToRegisterForRemoteNotifications(error: any Error) {
        AirshipLogger.error("Application failed to register for remote notifications with error \(error)")
        self.push.didFailToRegisterForRemoteNotifications(error)
    }

    @MainActor
    public func presentationOptions(for notification: UNNotification, completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            let options = await self.push.presentationOptionsForNotification(notification)
            completionHandler(options)
        }
    }

    @MainActor
    public func willPresentNotification(notification: UNNotification, presentationOptions: UNNotificationPresentationOptions, completionHandler: @escaping @Sendable () -> Void) {
        Task { @MainActor in
#if !os(tvOS) && !os(watchOS)
            _ = await self.processPush(
                notification.request.content.userInfo,
                isForeground: true,
                presentationOptions: presentationOptions
            )
#endif
            completionHandler()
        }
    }

    // MARK: - Response Handling (Conditional for tvOS)

#if !os(tvOS)
    @MainActor
    public func didReceiveNotificationResponse(response: UNNotificationResponse, completionHandler: @escaping @Sendable () -> Void) {
        AirshipLogger.info("Application received notification response: \(response)")

        let userInfo = response.notification.request.content.userInfo
        let categoryID = response.notification.request.content.categoryIdentifier
        let actionID = response.actionIdentifier
        let action = self.notificationAction(categoryID: categoryID, actionID: actionID)

        self.analytics.onNotificationResponse(response: response, action: action)

        Task { @MainActor in
            for component in pushableComponents {
                await component.receivedNotificationResponse(response)
            }

            if let actionsPayload = self.actionsPayloadForNotification(userInfo: userInfo, actionID: actionID) {
                let situation = self.situationFromAction(action) ?? .launchedFromPush
                let metadata: [String: any Sendable] = [
                    ActionArguments.userNotificationActionIDMetadataKey: actionID,
                    ActionArguments.pushPayloadJSONMetadataKey: try? AirshipJSON.wrap(userInfo),
                    ActionArguments.responseInfoMetadataKey: (response as? UNTextInputNotificationResponse)?.userText
                ]

                await ActionRunner.run(
                    actionsPayload: actionsPayload,
                    situation: situation,
                    metadata: metadata
                )
            }

            await self.push.didReceiveNotificationResponse(response)
            completionHandler()
        }
    }
#endif

    // MARK: - Remote Notification Handling

#if os(watchOS)
    @MainActor
    public func didReceiveRemoteNotification(userInfo: [AnyHashable : Any], isForeground: Bool, completionHandler: @escaping @Sendable (WKBackgroundFetchResult) -> Void) {
        self.processRemoteNotification(userInfo: userInfo, isForeground: isForeground) { result in
            completionHandler(result.osFetchResult)
        }
    }
#elseif os(macOS)
    @MainActor
    public func didReceiveRemoteNotification(
        userInfo: [AnyHashable : Any],
        isForeground: Bool
    ) {
        self.processRemoteNotification(
            userInfo: userInfo,
            isForeground: isForeground
        ) { _ in }
    }
#else
    @MainActor
    public func didReceiveRemoteNotification(userInfo: [AnyHashable : Any], isForeground: Bool, completionHandler: @escaping @Sendable (UIBackgroundFetchResult) -> Void) {
        self.processRemoteNotification(userInfo: userInfo, isForeground: isForeground) { result in
            completionHandler(result.osFetchResult)
        }
    }
#endif

    @MainActor
    private func processRemoteNotification(userInfo: [AnyHashable : Any], isForeground: Bool, completionHandler: @escaping @Sendable (UABackgroundFetchResult) -> Void) {
        guard !isForeground || AirshipUtils.isSilentPush(userInfo) else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            let result = await self.processPush(
                userInfo,
                isForeground: isForeground,
                presentationOptions: nil
            )
            completionHandler(result)
        }
    }

    // MARK: - Private Processing
    @MainActor
    private func processPush(
        _ userInfo: [AnyHashable: Any],
        isForeground: Bool,
        presentationOptions: UNNotificationPresentationOptions?
    ) async -> UABackgroundFetchResult {
        AirshipLogger.info("Application received remote notification: \(userInfo)")

        // Start with .noData as the baseline
        let finalResult = AirshipAtomicValue(UABackgroundFetchResult.noData)
        let wrappedUserInfo = self.safeWrap(userInfo: userInfo) ?? .null

        await withTaskGroup(of: UABackgroundFetchResult.self) { taskGroup in
            for component in pushableComponents {
                taskGroup.addTask {
                    return await component.receivedRemoteNotification(wrappedUserInfo)
                }
            }

            for await result in taskGroup {
                finalResult.update { $0.merge(result) }
            }
        }

        // Get and merge the platform-specific fetch result
        let fetchResult = await getFetchResult(userInfo, isForeground: isForeground)
        finalResult.update { $0.merge(fetchResult) }

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

        return finalResult.value
    }

    @MainActor
    private func getFetchResult(
        _ userInfo: [AnyHashable: Any],
        isForeground: Bool
    ) async -> UABackgroundFetchResult {
        return await self.push.didReceiveRemoteNotification(
            userInfo,
            isForeground: isForeground
        )
    }

    // MARK: - Helpers

    private func isForegroundPresentation(_ presentationOptions: UNNotificationPresentationOptions?) -> Bool {
        guard var options = presentationOptions else { return false }
        options.remove(.sound)
        options.remove(.badge)
        return options != []
    }

#if !os(tvOS)
    private func situationFromAction(_ action: UNNotificationAction?) -> ActionSituation? {
        guard let options = action?.options else { return nil }
        return options.contains(.foreground) ? .foregroundInteractiveButton : .backgroundInteractiveButton
    }

    private func actionsPayloadForNotification(userInfo: [AnyHashable: Any], actionID: String?) -> AirshipJSON? {
        guard let actionID = actionID, actionID != UNNotificationDefaultActionIdentifier else {
            return try? AirshipJSON.wrap(userInfo)
        }
        let interactive = userInfo["com.urbanairship.interactive_actions"] as? [AnyHashable: Any]
        return try? AirshipJSON.wrap(interactive?[actionID])
    }

    @MainActor
    private func notificationAction(categoryID: String, actionID: String) -> UNNotificationAction? {
        guard actionID != UNNotificationDefaultActionIdentifier else { return nil }

        let category = self.push.combinedCategories.first { $0.identifier == categoryID }
        if category == nil {
            AirshipLogger.error("Unknown notification category identifier \(categoryID)")
            return nil
        }
        let action = category?.actions.first { $0.identifier == actionID }
        if action == nil {
            AirshipLogger.error("Unknown notification action identifier \(actionID)")
        }
        return action
    }
#endif

    private func safeWrap(userInfo: [AnyHashable: Any]?) -> AirshipJSON? {
        guard let userInfo = userInfo else { return nil }
        if let json = try? AirshipJSON.wrap(userInfo) { return json }

        var parsed: [String: AirshipJSON] = [:]
        userInfo.forEach { (key, value) in
            if let stringKey = key as? String, let jsonValue = try? AirshipJSON.wrap(value) {
                parsed[stringKey] = jsonValue
            }
        }
        return try? AirshipJSON.wrap(parsed)
    }
}
