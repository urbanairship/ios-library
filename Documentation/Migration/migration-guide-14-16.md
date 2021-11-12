# Airship iOS SDK Migration Guide

**Due to a bug that mishandles persisted SDK settings, apps that are migrating from SDK 14.8.0 or older should update to 16.0.2 or newer**

# Airship SDK 14.x to 16.0.2


SDK 16.0 brings significant API changes to better support Swift. The core module has been completely rewritten in Swift, and some method signatures will have changed.

The prefix `UA` has been removed on the majority of classes, protocols, and enums. Most changes in code will just need the the `UA` prefix dropped in Swift. Objective-C will still have the `UA` prefix.

## Packaging Changes

`Airship` umbrella framework and `Airship` spm target has been removed. Use the modular components instead or use Cocoapods if you want all the modules to roll up into one.

When using xcframeworks or Carthage, you will need to add `AirshipBasement` with `AirshipCore` as bare minimum integration. The framework will be exported when you import AirshipCore, so there is no need to include an additional import just for AirshipBasement.


## Cocoapods import
The CocoaPods import has been updated from `Airship` to `AirshipKit`
```
// 14.x
import Airship

// 16.x
import AirshipKit
```

This is to avoid the class `Airship` from conflicting with the framework `Airship` to make it possible to use resolve any name conflicts with other frameworks.

## Shared Accessors

The class method `shared` has been converted to a class property through the SDK.

Example:

```
InAppAutomation.shared() -> InAppAutomation.shared
```

Objective-C usage will continue to work with both method and property syntax.

## Airship

Accessing `shared` and any components such as `push` and `channel` on `Airship` are now class properties instead of a class method. 

Example:

```
UAirship.push() -> Airship.push
```

### Nullability

The `Airship` instance no longer returns `null_unspecified` for its instances. Instead everything will now be `nonnull`, and if accessed before `takeOff` it will crash the application. `Airship.isFlying` can be used to check if the instances are ready or not without crashing.

### Take Off

The core module no longer uses class `load` methods, so takeOff now requires the launch options provided in the delegate method `application(_:didFinishLaunchingWithOptions:)`.

If you are unable to access the launch options, then you can setup an objective-c class with a class loader that adds an NSNotification for UIApplicationDidFinishLaunchingNotification that calls takeOff:

```
+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        
        [UAirship takeOffWithLaunchOptions:note.userInfo];
    }];
}
```

### Analytics Access

Analytics used to be accessible as both a class method and an instance property. Both have been removed in favor of a class property:

```
Airship.analytics
// or Analytics.shared
```

### Locale

The `locale` property has been renamed to `localeManager` on the Airship instance.

```
UAirship.shared().locale -> Airship.shared.localeManager
```

## Named User

- Note: Named User as an Airship feature is not deprecated. The deprecation is just for the previous SDK component `UANamedUser` in the SDK.

The `Named User` component in the SDK has been deprecated and replaced with the new `Contact` component. With contacts, setting tags and attributes does not require setting an external ID (Named User ID)

Identify a contact (Setting a named user ID):

```
Airship.contact.identify("some-user-id")
```

If the contact is going from anonymous to named, any tags and attributes will
carry forward to the contact when named if it does not already exist in Airship. If it does exist, the data will be dropped and a conflict event will be generated.

To reset the channel to an empty contact:

```
Airship.contact.reset()
```

Reset does not clear any data on the named user ID, instead it just assigns an empty anonymous user to the channel. 

Tags and attributes can be set using `editTagGroups` and `editAttributes`:

```
Airship.contact.editTagGroups { editor in
    editor.add(["some-tag"], group: "some-group")
}

Airship.contact.editAttributes { editor in
    editor.set(string: "some-attribute-value", attribute: "some-attribute")
}
```

## Channel

### Tags, Tag Groups, and Attributes
As with Contacts, to edit tags, tag groups, and attributes use the new editors:

```
Airship.channel.editTagGroups { editor in
    editor.add(["some-tag"], group: "some-group")
}

Airship.channel.editAttributes { editor in
    editor.set(string: "some-attribute-value", attribute: "some-attribute")
}

Airship.channel.editTags { editor in 
    editor.add("tag")
}
```

The method `updateRegistration` was deprecated without a replacement. It is no longer required to call as the SDK will automatically queue up an update when it detects a change.

### NSNotifications

The constants for NSNotification names have moved:

```
UAChannelCreatedEvent -> Channel.channelCreatedEvent
UAChannelUpdatedEvent -> Channel.channelUpdatedEvent
```


## Push

### Notification wrapper classes

`UANotification`, `UANotificationContent`, `UANotificationResponse`, `UANotificationCategory`, and `UANotificationAction` have been removed to make it easier to adopt changes to those classes in new iOS release without
waiting on Airship to update the wrappers. These classes outlived their usefulness. Instead of the `UA` version, use the `UN` version provided by Apple.

### NSNotifications

The constants for NSNotification names have moved:

```
UAReceivedNotificationResponseEvent -> Push.receivedNotificationResponseEvent
UAReceivedForegroundNotificationEvent -> Push.receivedForegroundNotificationEvent
UAReceivedBackgroundNotificationEvent -> Push.receivedBackgroundNotificationEvent
```

The `receivedNotificationResponseEvent` no longer only contains the userInfo of the response in the notification. Instead, the entire response is available under the key `Push.receivedNotificationResponseEventResponseKey`.

### PushNotificationDelegate

The `PushNotificationDelegate` has been updated to no longer reference UA wrappers for notifications and responses:

SDK 14:
```
func receivedBackgroundNotification(_ notificationContent: UANotificationContent, completionHandler: @escaping (UIBackgroundFetchResult) -> Void)

func receivedForegroundNotification(_ notificationContent: UANotificationContent, completionHandler: @escaping () -> Void)
 
func receivedNotificationResponse(_ notificationResponse: UANotificationResponse, completionHandler: @escaping () -> Void)

func extend(_ options: UNNotificationPresentationOptions = [], notification: UNNotification) -> UNNotificationPresentationOptions
```

SDK 16:

```    
func receivedBackgroundNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void)

func receivedForegroundNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void)

func receivedNotificationResponse(_ notificationResponse: UNNotificationResponse, completionHandler: @escaping () -> Void)

func extend(_ options: UNNotificationPresentationOptions, notification: UNNotification) -> UNNotificationPresentationOptions
```

## Privacy Manager

### NSNotifications

The constants for NSNotification names have moved:
```
 UAPrivacyManagerEnabledFeaturesChangedEvent -> UAPrivacyManager.changeEvent
```

### API changes

In swift, the API to disable features changed slightly:

```
UAirship.shared().privacyManager.disable(.push) -> Airship.shared.privacyManager.disableFeatures(.push)
```

## Actions

`UAAction` is now just a protocol instead of a concrete class. `BlockAction` was added to make it easy to provide a closure instead of defining a concrete class.  

When registering actions in the `ActionRegistry`, the entry is no longer mutable. The action registry has been updated to allow updating the predicate directly instead of mutating the entry.
  
## LocaleManager

The locale manager no longer allows resetting the locale by setting the value to nil. Instead use the `clearLocale` method:

14.x:
```
UAirship.shared().locale.currentLocale = nil
```

16.x:
```
Airship.shared.localeManager.clearLocale()
```
