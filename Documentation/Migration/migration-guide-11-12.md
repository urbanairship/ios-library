# Airship iOS SDK Migration Guide

# Airship SDK 11.x to 12.0

Airship SDK 12 is a compatibility release for iOS 13 support. It adds a number of new optional features and drops support for iOS 10. This release also drops all references to UIWebView in favor of WKWebView.

## UAPush Changes

The UAPush class has been reorganized to refactor channel-related functionality into a new UAChannel class. Channel creation, access and tagging are now handled through the UAChannel class. These functions will remain accessible in a deprecated state on the UAPush instance, but are scheduled to be removed with the release of SDK 13.

#### Deprecated (to be removed in SDK 13):
* `channelID`
* `tags`
* `channelTagRegistrationEnabled`
* `addTag:`
* `addTags:`
* `removeTag:`
* `removeTags:`
* `addTags:group:`
* `removeTags:group:`
* `setTags:group:`
* `enableChannelCreation:`
    * Use [UAChannel](https://docs.airship.com/reference/libraries/ios/12.0.0/Classes/UAChannel.html) to access these properties and methods.

### UAPushNotificationDelegate

#### Deprecated (to be removed in SDK 13):
* `presentationOptionsForNotification:`
    * Use UAPushNotificationDelegate's `extendPresentationOptions:notification:`

### UARegistrationDelegate

#### Deprecated (to be removed in SDK 13):
* `registrationSucceededForChannelID:deviceToken:`
    * Use the `UAChannelUpdatedEvent` NSNotificationCenter notification

* `registrationFailed`
    * Use the `UAChannelRegistrationFailedEvent` NSNotificationCenter notification

### UAChannel

The [UAChannel](https://docs.airship.com/reference/libraries/ios/12.0.0/Classes/UAChannel.html) class now handles channel creation, access and tagging functionality. Use this class when accessing any channel-related functionality previously implemented in the UAPush class. 

The UAChannel class instance can be accessed on the UAirship instance via the following calls:

Objective-c:
```objective-c
[UAirship channel]
```

Swift:
```swift
UAirship.channel()
```

The channel identifier can now be accessed via the following calls:

Objective-c:
```objective-c
[[UAirship channel] identifier]
```

Swift:
```swift
UAirship.channel()?.identifier
```

## In-app Automation Scene Management

Support for UIWindowScenes introduced in iOS 13 is provided by the UAInAppMessageSceneManager and the UAInAppMessageSceneDelegate. The UAInAppMessageSceneManager class facilitates scene determination for in-app messages directly and via it's delegate the UAInAppMessageSceneDelegate. 

### UAInAppMessageSceneManager

In-app message adapters can use the [UAInAppMessageSceneManager](https://docs.airship.com/reference/libraries/ios/12.0.0/Classes/UAInAppMessageSceneManager.html) to select the correct UIWindowScene on which to display messages. Scenes can be determined directly on a message by message basis via the following calls:

Objective-c:
```objective-c
[[UAInAppMessageSceneManager shared] sceneForMessage:exampleMessage];
```

Swift:
```swift
UAInAppMessageSceneManager.shared().scene(for:exampleMessage)
```

### UAInAppMessageSceneDelegate

The [UAInAppMessageSceneDelegate](https://docs.airship.com/reference/libraries/ios/12.0.0/Classes/UAInAppMessageSceneDelegate.html) facilitates overriding the UIWindowScene on which a given in-app message is displayed. 

The UAInAppMessageSceneDelegate can be set as the UAInAppMessageSceneManager delegate via the following calls: 

Objective-c:
```objective-c
[UAInAppMessageSceneManager shared].delegate = exampleInAppMessagerSceneDelegate;
```

Swift:
```swift
UAInAppMessageSceneManager.shared().delegate = exampleInAppMessagerSceneDelegate
```

## Dark Mode Support

### UAMessageCenterStyle

Message Center can now be styled with named colors by setting named colors as strings in the message center style plist. These named color strings must correspond to a named color defined in a color asset within the main bundle. In addition to this, the navigation bar style can also now be set to accomodate black bar styles.