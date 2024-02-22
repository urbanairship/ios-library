# Airship iOS SDK 17.x to 18.0 Migration Guide

## Xcode requirements

SDK 18.x now requires Xcode 15.2 or newer.

## Airship Components

Instead of a mix of class vars and instance vars to access various components on the `Airship` instance, they have been normalized to just class vars.

| SDK 17.x                                 | SDK 18.x                           |
| -----------------------------------------|------------------------------------|
| Airship.shared.config                    | Airship.config                     |
| Airship.shared.actionRegistry            | Airship.actionRegistry             |
| Airship.shared.permissionsManager        | Airship.permissionsManager         |
| Airship.shared.javaScriptCommandDelegate | Airship.javaScriptCommandDelegate  |
| Airship.shared.channelCapture            | Airship.channelCapture             |
| Airship.shared.deepLinkDelegate          | Airship.deepLinkDelegate           |
| Airship.shared.urlAllowList              | Airship.urlAllowList               |
| Airship.shared.localeManager             | Airship.localeManager              |
| Airship.shared.privacyManager            | Airship.privacyManager             |
| Airship.shared.applicationMetrics        | Removed, this is internal only now |


Protocols are exposed instead of concrete classes on Airship to better hide implementation details.

| SDK 17.x                                 | SDK 18.x                           |
|------------------------------------------|------------------------------------|
| URLAllowList                             | URLAllowListProtocol               |
| AirshipLocaleManager                     | AirshipLocaleManagerProtocol       |
| AirshipPush                              | AirshipPushProtocol                |
| AirshipContact                           | AirshipContactProtocol             |
| AirshipAnalytics                         | AirshipAnalyticsProtocol           |
| AirshipChannel                           | AirshipChannelProtocol             |

`AirshipPush`, `AirshipContact`, `AirshipAnalytics`, and `AirshipChannel` are all internal classes now, the shared methods on those classes have been removed. Instead,
use the `Airship.push`, `Airship.contact`, `Airship.analytics`, and `Airship.channel` class vars instead.

## NotificationCenter (NSNotificationCenter)

Notification Center events emitted by the Airship SDK have been updated. Most the notifications are still available, except channel updated. The constants for the rest have been moved.

#### Airship Ready Event

17.x:
```
    NotificationCenter.default.addObserver(
        forName: Airship.airshipReadyNotification,
        object: nil,
        queue: nil
    ) { notification in
        /// Following values are only available if `extendedBroadcastEnabled` is true in config.
        let appKey = notification.userInfo?[Airship.airshipReadyAppKey] as? String
        let payloadVersion = notification.userInfo?[Airship.airshipReadyPayloadVersion] as? Int
        let channelID = notification.userInfo?[Airship.airshipReadyChannelIdentifier] as? String
    }
```

18.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipNotifications.AirshipReady.name,
        object: nil,
        queue: nil
    ) { notification in
        /// Following values are only available if `extendedBroadcastEnabled` is true in config.
        let appKey = notification.userInfo?[AirshipNotifications.AirshipReady.appKey] as? String
        let payloadVersion = notification.userInfo?[AirshipNotifications.AirshipReady.payloadVersionKey] as? Int
        let channelID = notification.userInfo?[AirshipNotifications.AirshipReady.channelIDKey] as? String
    }
```

#### Channel Created

17.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipChannel.channelCreatedEvent,
        object: nil,
        queue: nil
    ) { notification in
        let channelID = notification.userInfo?[AirshipChannel.channelIdentifierKey] as? String
        let isExisting = notification.userInfo?[AirshipChannel.channelExistingKey] as? Bool ?? false
    }
```

18.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipNotifications.ChannelCreated.name,
        object: nil,
        queue: nil
    ) { notification in
        let channelID = notification.userInfo?[AirshipNotifications.ChannelCreated.channelIDKey] as? String
        let isExisting = notification.userInfo?[AirshipNotifications.ChannelCreated.isExistingChannelKey] as? Bool ?? false
    }
```

#### Channel Updated

Channel updated has been removed. For the most part apps should not need that and most likely are trying to listen for opt-in status. For that, see `notificationStatus` on the `PushProtocol`.


#### Received Notifications

The foreground and background notifications have been collapsed into a single event with a userInfo key indicating foreground vs background.

17.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipPush.receivedForegroundNotificationEvent,
        object: nil,
        queue: nil
    ) { notification in
        let isForeground = true
        let receivedNotification = notification.userInfo
    }

    NotificationCenter.default.addObserver(
        forName: AirshipPush.receivedBackgrounddNotificationEvent,
        object: nil,
        queue: nil
    ) { notification in
        let isForeground = false
        let receivedNotification = notification.userInfo
    }
```

18.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipNotifications.RecievedNotification.name,
        object: nil,
        queue: nil
    ) { notification in
        let isForeground = notification.userInfo?[AirshipNotifications.RecievedNotification.isForegroundKey] as? Bool
        let receivedNotification = notification.userInfo?[AirshipNotifications.RecievedNotification.notificationKey] as? [AnyHashable: Any]
    }
```

#### Received Notification Response

17.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipPush.receivedNotificationResponseEvent,
        object: nil,
        queue: nil
    ) { notification in
        let response = notification.userInfo?[AirshipPush.receivedNotificationResponseEventResponseKey]
    }
```

18.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipNotifications.ReceivedNotificationResponse.name,
        object: nil,
        queue: nil
    ) { notification in
        let response = notification.userInfo?[AirshipNotifications.ReceivedNotificationResponse.responseKey]
    }
```

#### Locale Updated

17.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipLocaleManager.localeUpdatedEvent,
        object: nil,
        queue: nil
    ) { notification in
        let locale = notification.userInfo?[AirshipLocaleManager.localeEventKey] as? Locale
    }
```

18.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipNotifications.LocaleUpdated.name,
        object: nil,
        queue: nil
    ) { notification in
        let response = notification.userInfo?[AirshipNotifications.LocaleUpdated.localeKey] as? Locale
    }
```

#### Privacy Manager Updated

17.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipPrivacyManager.localechangeEventUpdatedEvent,
        object: nil,
        queue: nil
    ) { _ in
        
    }
```

18.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipNotifications.PrivacyManagerUpdated.name,
        object: nil,
        queue: nil
    ) { _ in
        
    }
```

#### Contact Conflict Event

17.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipContact.contactConflictEvent,
        object: nil,
        queue: nil
    ) { notification in
        let conflictEvent = notification.userInfo?[AirshipContact.contactConflictEventKey] as? ContactConflictEvent
    }
```

18.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipNotifications.ContactConflict.name,
        object: nil,
        queue: nil
    ) { notification in
        let conflictEvent = notification.userInfo?[AirshipNotifications.ContactConflict.eventKey] as? ContactConflictEvent
    }
```

#### Message Center Updated

17.x:
```
    NotificationCenter.default.addObserver(
        forName: MessageCenterInbox.messageListUpdatedEvent,
        object: nil,
        queue: nil
    ) { _ in
        
    }
```

18.x:
```
    NotificationCenter.default.addObserver(
        forName: AirshipNotifications.MessageCenterListUpdated.name,
        object: nil,
        queue: nil
    ) { _ in
        
    }
```



## Adding Events

The Analytics method `addEvent(_)` has been removed and replaced with `recordRegionEvent(_)` and `recordCustomEvent(_)`

| SDK 17.x                                | SDK 18.x
| ----------------------------------------|---------------------------------------------------|
| Airship.analytics.addEvent(customEvent) | Airship.analytics.recordCustomEvent(customEvent) |
| Airship.analytics.addEvent(regionEvent) | Airship.analytics.recordRegionEvent(regionEvent) |


## AirshipAutomation

The `AirshipAutomation` module has been rewritten in swift and no longer supports obj-c bindings. For most apps, this will be a trivial update, but if you are using custom display adapters the update will be more extensive. See below for more on custom display adapters.

### Accessors

The accessors for `InAppMessaging` and `LegacyInAppMessaging` have moved.

| SDK 17.x                                    | SDK 18.x                                    |
|---------------------------------------------|---------------------------------------------|
| InAppAutomation.shared.inAppMessageManager  | InAppAutomation.shared.inAppMessaging       |
| LegacyInAppMessaging.shared                 | InAppAutomation.shared.legacyInAppMessaging |

### Cache Management

`InAppMessagePrepareAssetsDelegate`, `InAppMessageCachePolicyDelegate`, `InAppMessageAssetManager` have been removed and is no longer available to extend. These APIs were difficult to use and often times lead to unintended consequences. The Airship SDK will now manage its own assets.  External assets required by the App that need to be fetched before hand should happen outside of Airship. If assets are needed and can be fetched at display time, use the `CustomDisplayAdapter.waitForReady()` method as a hook to fetch those assets.

### Display Coordinators

Display coordinators was another difficult to use API that has been removed. Instead, use the `InAppMessageDisplayDelegate.isMessageReadyToDisplay(_:scheduleID:)` method to prevent messages from displaying, and `InAppAutomation.shared.inAppMessaging.notifyDisplayConditionsChanged()` to notify when the message should be tried again. If a use case is not able to be solved with the replacement methods, please file a Github issue with your use case.

### Extending messages

InAppMessages are no longer extendable when displaying. If this is needed in your application, please file a Github issue with your use case.

### Custom Display Adapter

`InAppMessageAdapterProtocol` has been replaced with `CustomDisplayAdapter`. The new protocol has changed, but it roughly provides the same functionality as before just with a different interface.


| SDK 17.x   `InAppMessageAdapterProtocol`                                           | SDK 18.x `CustomDisplayAdapter`                                                        |
| -----------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| adapter(for:)                                                                      | No mapping, no required factory method                                                 |
| display() async -> InAppMessageResolution                                          | display(scene: UIWindowScene) async -> CustomDisplayResolution                         |
| func prepare(with assets: InAppMessageAssets) async -> InAppMessagePrepareResult   | use isReady and func waitForReady() async. Asset are available in the factory callback |
| isReadyToDisplay                                                                   | isReady                                                                                |


Example:

```
final class MyCustomDisplayAdapter : CustomDisplayAdapter {

    @MainActor
    static func register() {
        InAppAutomation.shared.inAppMessaging.setAdapterFactoryBlock(forType: .banner) { message, assets in
            return MyCustomDisplayAdapter(message: message, assets: assets)
        }
    }

    let message: InAppMessage
    let assets: AirshipCachedAssetsProtocol

    init(message: InAppMessage, assets: AirshipCachedAssetsProtocol) {
        self.message = message
        self.assets = assets
    }

    @MainActor
    var isReady: Bool {
        // This is called before the message is displayed. If `false`, `waitForReady()` will
        // be called before this is checked again. If `true`, `display` will  be called
        // on the same run loop
        return true
    }

    @MainActor
    func waitForReady() async {
        /// If `isReady` is false, this method should wait for whatever conditions are required to make `isReady` true.
    }

    @MainActor
    func display(scene: UIWindowScene) async -> CustomDisplayResolution {
        /// Most apps will probably need a continuation
        return await withCheckedContinuation { continuation in

            /// Display the message


            /// Resume with the results after its been displayed. Failing to resume will block other messages
            /// from displaying
            continuation.resume(returning: CustomDisplayResolution.userDismissed)
        }
    }
}
```

Then, after takeOff:
```
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        ...

        Airship.takeOff(config, launchOptions: launchOptions)
        MyCustomDisplayAdapter.register()

        ...
    }
```


