# Airship iOS SDK 16.x to 17.0 Migration Guide

## Xcode requirements

SDK 17.x now requires Xcode 14.3 or newer.

## Minimum deployment version

SDK 17.x is compatible with iOS 14+. Apps using Airship will need to update the minimum deployment version.

## Removed modules

The following modules are no longer supported and have been removed from the SDK:

### `AirshipAccengage`

Users of Accengage should remove the `AirshipAccengage` module from their project after completing the migration process.
For further information about migration and removal, see the [Accengage Migration guide](https://docs.airship.com/platform/mobile/accengage-migration/migration/ios/index.html#remove-airship-accengage-module).

### `AirshipChat`

The Airship Chat module is no longer supported and has been removed from the SDK.

### `AirshipLocation`

The Airship Location module is no longer supported and has been removed from the SDK. If you want to continue prompting users for location permissions, you must update your integration to set a location permission delegate on the `PermissionsManager`:

```
import Foundation
import CoreLocation
import AirshipCore
import Combine

class LocationPermissionDelegate: AirshipPermissionDelegate {
    let locationManager = CLLocationManager()

    @MainActor
    func checkPermissionStatus() async -> AirshipCore.AirshipPermissionStatus {
        return self.status
    }

    @MainActor
    func requestPermission() async -> AirshipCore.AirshipPermissionStatus {
        guard (self.status == .notDetermined) else {
            return self.status
        }

        guard (AppStateTracker.shared.state == .active) else {
            return .notDetermined
        }

        locationManager.requestAlwaysAuthorization()
        await waitActive()
        return self.status
    }


    var status: AirshipPermissionStatus {
        switch(locationManager.authorizationStatus) {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .denied
        case .denied:
            return .denied
        case .authorizedAlways:
            return .granted
        case .authorizedWhenInUse:
            return .granted
        @unknown default:
            return .notDetermined
        }
    }
}


@MainActor
private func waitActive() async {
    var subscription: AnyCancellable?
    await withCheckedContinuation { continuation in
        subscription = NotificationCenter.default.publisher(for: AppStateTracker.didBecomeActiveNotification)
            .first()
            .sink { _ in
                continuation.resume()
            }
    }

    subscription?.cancel()
}
```

Then after takeOff, register the permission delegate for the location permission:
```
Airship.shared.permissionsManager.setDelegate(
    LocationPermissionDelegate(),
    permission: .location
)
```

### `AirshipExtendedActions`

The Airship Extended Actions only contained the RateAppAction which is now available in the core module.

## Allowed URLs

The URL allow list configuration has been changed to an opt-out process, rather than an opt-in process like previous SDK versions.
By default, all URLs are allowed by SDK 17, unless explicitly disallowed by the app via the `urlAllowList` or `urlAllowListScopeOpen` config options.

Allow list behavior changes:
- If neither `urlAllowList` or `urlAllowListScopeOpenURL` are set in your Airship config, the SDK will default to allowing all URLs and an error message will be logged.
- To suppress the error message, set `urlAllowList` or `urlAllowListScopeOpenURL` to `[*]` to your config to adopt the new allow-all behavior, or customize the allowed URLs as needed.
- URLs for media displayed within in-app messages will no longer be checked against the URL allow lists.
- YouTube has been removed from the default allow list. If your application makes use of opening links to YouTube from Airship messaging, you will need to update your allow list to explicitly allow `youtube.com`, or allow all URLs with `[*]`.

## Renamed classes

Some common class names have been renamed to prevent collisions with other libraries/apps:

| Legacy class name  | New class name  |
| -------------------| ----------------|
| Config             | AirshipConfig   |
| Channel            | AirshipChannel  |
| Contact            | AirshipContact  |
| Push               | AirshipPush     |
| PrivacyManager     | AirshipPrivacyManager|
| Analytics          | AirshipAnalytics|
| Action             | AirshipAction |
| Situation          | ActionSituation |
| Features           | AirshipFeature |
| Event              | AirshipEvent |


## In-App Automation

### Updated the default display interval for In-App Messages

The new default display interval for in-app messages is now set to 0 seconds. Apps that wish to maintain the previous default display interval of 30 seconds should set the display interval manually, after takeOff:

```
InAppAutomation.shared.inAppMessageManager.displayInterval = 30.0
```

### Deep link delegate 

Deep link delegate is now async.

SDK 16:
```
deepLinkDelegate.receivedDeepLink(deepLink) {
    completionHandler(true)
}
```

SDK 17:
```
await deepLinkDelegate.receivedDeepLink(deepLink) {
    completionHandler(true)
}  
```

## Contacts

### Contact conflict listener interface updated

Contact conflict event is now available as a NSNotification or using `Airship.contact.conflictEventPublisher` to listen for events:

SDK 16:
```
conflictDelegate?.onConflict(anonymousContactData: anonData, namedUserID: namedUserID)
```

SDK 17:
```
Airship.contact.conflictEventPublisher.sink { event in
    // ...
}
    
NotificationCenter.default.addObserver(
    self,
    selector: #selector(conflictEventReceived),
    name: AirshipContact.contactConflictEvent
)
```

### Async Named User ID access

Named User ID access is now an async property:

SDK 16:
```
let namedUserID = Airship.contact.namedUserID
```

SDK 17:
```
let namedUserID = await Airship.contact.namedUserID
```

### Async Subscription lists access 

Subscription list is now an async method:

SDK 16:
```
Airship.contact.fetchSubscriptionLists { contactSubscriptionLists, error in
    // Use the contactSubscriptionLists
}
```

SDK 17:
```
let contactSubscriptions = try await Airship.contact.fetchSubscriptionLists
```

## Channels

### Async Subscription lists access 

Subscription list is now an async method:

SDK 16:
```
Airship.channel.fetchSubscriptionLists { channelSubscriptionLists, error in
    // Use the channelSubscriptionLists
}
```

SDK 17:
```
let channelSubscriptions = try await Airship.channel.fetchSubscriptionLists
```

### Live Activities

The API's to track and restore live activity tracking have been updated to no longer require a Task:

SDK 16:
```
Task {
    await Airship.channel.trackLiveActivity(
    activity,
    name: "order-1234"
)

Task {
    await Airship.channel.restoreLiveActivityTracking { restorer in
        await restorer.restore(
            forType: Activity<DeliveryAttributes>.self
        )
        await restorer.restore(
            forType: Activity<SomeOtherAttributes>.self
        )
    }
}
```

SDK 17:
```
Airship.channel.trackLiveActivity(
    activity,
    name: "order-1234"
)

Airship.channel.restoreLiveActivityTracking { restorer in
    await restorer.restore(
        forType: Activity<DeliveryAttributes>.self
    )
    await restorer.restore(
        forType: Activity<SomeOtherAttributes>.self
    )
}
```

## Message Center

The MessageCenter module has been rewritten in Swift and the OOTB UI in SwiftUI. With the rewrite, we are providing a new set of APIs that take advantage of Swift's structured concurrency.

### Message listing API Changes

All methods on the Message Center for listing are now async, and the listing is no longer stored in memory.

#### Accessing message list

SDK 16:
```
let messages = MessageCenter.shared.messageList.messages
```

SDK 17:
```
let messages = await MessageCenter.shared.inbox.messages
```

#### Deleting a message

SDK 16:
```
MessageCenter.shared.messageList.markMessagesDeleted([message]) { // completed }
```

SDK 17:
```
// by message ID
await MessageCenter.shared.inbox.delete(messageIDs: ["messageID"])

// by message
await MessageCenter.shared.inbox.delete(messages: [message])
```

#### Marking a message as read

SDK 16:
```
MessageCenter.shared.messageList.markMessagesRead([message]) { // completed }
```

SDK 17:
```
// by message ID
await MessageCenter.shared.inbox.markRead(messageIDs: ["messageID"])

// by message
await MessageCenter.shared.inbox.markRead(messages: [message])
```

#### Refreshing the message listing

SDK 16:
```
MessageCenter.shared.messageList.retrieveMessageList(successBlock: {
   // handle success
}, withFailureBlock: {
    // handle failure
})
```

SDK 17:
```
await MessageCenter.shared.inbox.refreshMessages()
```

#### Listening to message listing updates


### Message Center UI

Now our Message Center View has been rewritten using SwiftUI. The UIKit based views have been removed.

#### Embedding Message Center in SwiftUI

```
struct CustomMessageCenter: View {
    let controller = MessageCenterController()
    
    var body: some View {
        MessageCenterView(controller: controller)
    }
}
```

#### Embedding Message Center in UIKit

SDK 16:

```
import AirshipKit

class MessageCenterViewController : DefaultMessageCenterSplitViewController {

}
```

SDK 17:
```
// 1
let messageCenterviewController = MessageCenterViewControllerFactory.make(
controller: controller
)

if let messageCenterView = messageCenterviewController.view {
    // 2
    // Add the message center view controller to the destination view controller.
    addChild(messageCenterviewController)
    view.addSubview(messageCenterView)

    // 3
    // Create and activate the constraints.
    messageCenterView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        messageCenterView.topAnchor.constraint(equalTo: view.topAnchor),
        messageCenterView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        messageCenterView.leftAnchor.constraint(equalTo: view.leftAnchor),
        messageCenterView.rightAnchor.constraint(equalTo: view.rightAnchor),
    ])
}
```

#### Theming

`MessageCenterStyle` has been renamed to `MessageCenterTheme` to avoid confusing with SwiftUI style patterns.

SDK 16:
```
let style = MessageCenterStyle()

MessageCenter.shared.defaultUI.style = style
```

SDK 17:
```
var messageCenterTheme = MessageCenterTheme()

MessageCenter.shared.theme = messageCenterTheme
```

You can also set the theme on the MessageCenterView directly:

Example:

```
MessageCenterView(controller: controller)
    .messageCenterTheme(CustomMessageCenter.messageCenterTheme)
```

### Load custom message center message view

#### Fetch user credentials:

SDK 16:
```
MessageCenter.shared.user.getData { user in
    // ...
}
```

SDK 17:
```
let user = await MessageCenter.shared.inbox.user
```

#### Load  webView:

The example below shows how to fetch the credentials, set auth on the request, and load a message into the webview. 
This code assumes a custom view controller with an embedded WKWebView, as well as a `MessageCenterMessage` ready to be loaded.

SDK 16:
```
let requestObj = NSMutableURLRequest(url:message.messageURL) 
MessageCenter.shared.user.getData { data in 

    // set the auth 
    let auth = Utils.authHeaderString(withName: data.username, password: data.password) 
    requestObj.setValue(auth, forHTTPHeaderField:"Authorization")

    // load the request 
    self.webView.load(requestObj) 

}, queue: DispatchQueue.main)
```

SDK 17:

```
var request = URLRequest(url: message.bodyURL)
let user = await MessageCenter.shared.inbox.user
                
// set the auth
request.setValue(user.basicAuthString, forHTTPHeaderField: "Authorization")
                
// load the request
self.webView.load(request)
```

## Preference Center

### Preference Center UI

The Preference Center UI has been rewritten in SwiftUI.


#### Embedding Preference Center in SwiftUI

```
PreferenceCenterView(preferenceCenterID: "preferenceCenter-ID")
```

#### Embedding Preference Center in UIKit

```
// 1
let preferenceCenterviewController = PreferenceCenterViewControllerFactory.makeViewController(preferenceCenterID: "neat")

if let preferenceCenterView = preferenceCenterviewController.view {

    // 2
    // Add the prefrence center view controller to the destination view controller.
    addChild(preferenceCenterviewController)
    view.addSubview(preferenceCenterView)

    // 3
    // Create and activate the constraints.
    preferenceCenterView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        preferenceCenterView.topAnchor.constraint(equalTo: view.topAnchor),
        preferenceCenterView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        preferenceCenterView.leftAnchor.constraint(equalTo: view.leftAnchor),
        preferenceCenterView.rightAnchor.constraint(equalTo: view.rightAnchor),
    ])
}
```

### Theme

`PreferenceCenterStyle` has been replaced by `PreferenceCenterTheme`.

SDK 16:
```
let style = PreferenceCenterStyle()

PreferenceCenter.shared.style = style
```

SDK 17:
```
var theme = PreferenceCenterTheme()

PreferenceCenter.shared.theme = theme
```

A theme can also be set directly on the PreferenceCenterView:

```
 PreferenceCenterView(preferenceCenterID: "preferenceCenterID")
    .preferenceCenterTheme(theme)
```

## Actions

Actions have been rewritten to use async/await and be Sendable.


### Registering actions

SDK 16:
```
Airship.shared.actionRegistry.register(action, names: ["action_name", "action_alias"])
```

SDK 17:
```
Airship.shared.actionRegistry.registerEntry(names: ["action_name", "action_alias"]) {
    return ActionEntry(action: action)
}
```

### Defining actions

SDK 16:
```
let customAction = BlockAction { args, completionHandler in
    print("Action is performing with args: \(args)")
    completionHandler(ActionResult.empty())
}
```

SDK 17:
```
let customAction = BlockAction { args in
    print("Action is performing with args: \(args)")
    return nil
}
```

### Running actions

SDK 16:
```
// Run an action by name
ActionRunner.run("action_name", value: "action_value", situation: .manualInvocation) { result in
    print("Action finished!")
}

// Run an action directly
ActionRunner.run(action, value: "action_value", situation: .manualInvocation) { result in
    print("Action finished!")
}
```

SDK 17:
```
// Run an action by name
let result = await ActionRunner.run(
    actionName: "action_name",
    arguments: ActionArguments(
        string: "action_value",
        situation: .manualInvocation
    )
)

// Run an action directly
let result = await ActionRunner.run(
    action: action,
    arguments:ActionArguments(
        string: "action_value",
        situation: .manualInvocation
    )
)
            
```

