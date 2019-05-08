# Airship iOS SDK Migration Guide

# Airship Library 10.x to 11.0

This release makes a breaking change to the way the SDK manages location services.
The core SDK now contains no references to CoreLocation APIs, and the `UALocation`
module has been broken out into a separate framework, `AirshipLocationKit`. The module
itself remains largely unchanged, but apps using it must import and link against
`AirshipLocationKit` in order to access it. In place of the static `location` accessor
on `UAirship`, a `shared` accessor has been added to `UALocation` for retrieving the
singleton instance for the module.

In addition, a new protocol named
`UALocationProviderDelegate` has been added, along with an assignable delegate property on
`UAirship`, which maps to the `UALocation` module by default and which be overridden
with custom location providers in advanced use cases.

## UAirship

### Added

* `locationProviderDelegate`

### Removed

* `location`

## UALocation

### Added

* `shared`

## UALocationEvent

This class no longer requires references to `CoreLocation`, including `CLLocation` objects.
All methods previously requiring CLLocation objects have been changed to take `UALocationEventInfo`
objects, which encapsulate the relevant data.

### Added

* `locationEventWithInfo:providerType:desiredAccuracy:distanceFilter`
* `singleLocationEventWithInfo:providerType:desiredAccuracy:distanceFilter`
* `standardLocationEventWithInfo:providerType:desiredAccuracy:distanceFilter`
* `significantChangeLocationEventWithInfo:providerType`

### Removed

* `locationEventWithLocation:providerType:desiredAccuracy:distanceFilter`
* `singleLocationEventWithLocation:providerType:desiredAccuracy:distanceFilter`
* `standardLocationEventWithLocation:providerType:desiredAccuracy:distanceFilter`
* `significantChangeLocationEventWithLocation:providerType`

## UALocationProviderDelegate

This protocol is new as of 11.0, and the default implementation is found in the `UALocation` module
in `AirshipLocationKit`. The core SDK uses the protocol in order to negotiate location settings with
the `UALocation` module, as well as for reporting purposes. In advanced use cases, apps can override
the `locationProviderDelegate` property on `UAirship` to set a custom provider, which can then be
used in place of the `UALocation` module, while allowing features such as location reporting and
location-based In-App Automation audience conditions to function normally.

# Airship Library 10.x to 10.2

This release consists mostly of bugfixes and enhancements to In-App Automation, but some deprecations were made due
to changes in how the SDK accesses data in the Keychain.

## UAUserData

This class encapsulates all the relevant data associated with a `UAUser` instance, including the username,
password, and URL. The data is accessed asynchronously from the Keychain.

## UAUser

### Added

* `getUserData:`

### Deprecated (to be removed in SDK 11)

* `username`
* `password`
* `url`

Instead of using these properties, apps requiring access to the user data should call `getUserData:`, which
takes an asynchronous callback. While the above properties will continue to work in deprecation, they are
synchronous and potentially blocking, and so their use is discouraged. Any apps using these properties are strongly
recommended to use the new asynchronous getter.

## UAUtils

### Deprecated (to be removed in SDK 11)

* `deviceID`

As with the `UAUser` properties mentioned above, this property will continue to function in deprecation, but it
is similarly blocking and so its use is discouraged. In addition, as apps should not be using this data, as of SDK 11.0 it
will become an internal-only feature with no public replacement.

# Airship Library 9.x to 10.0

This is a compatibility release for iOS 12 support, mostly adding new optional features. However some breaking changes have been made
in order to support them. Since iOS 8 is no longer supported, some iOS 8 specific workarounds have been removed, as well as items previously
marked deprecated to be removed in SDK 10.

## Notification Authorization

Notification authorization settings and authorization status is now fully decoupled from requested options. Use `UAAuthorizedNotificationSettings`
and `UAAuthorizationStatus` in order to determine which notification settings are authorized following push registration at runtime.

### UAAuthorizationStatus

* `UAAuthorizationStatusNotDetermined`
* `UAAuthorizationStatusDenied`
* `UAAuthorizationStatusAuthorized`
* `UAAuthorizationStatusProvisional`

### UAAuthorizedNotificationSettings

* `UAAuthorizedNotificationSettingsNone`
* `UAAuthorizedNotificationSettingsBadge`
* `UAAuthorizedNotificationSettingsSound`
* `UAAuthorizedNotificationSettingsAlert`
* `UAAuthorizedNotificationSettingsCarPlay`
* `UAAuthorizedNotificationSettingsLockScreen`
* `UAAuthorizedNotificationsSettingsNotificationCenter`
* `UAAuthorizedNotificationsSettingsCriticalAlert`

## UARegistrationDelegate

Registration delegate methods have been updated to reflect the new authorization model described above.

### Added

* `notificationRegistrationFinishedWithAuthorizedSettings:categories:status`
* `notificationAuthorizedSettingsDidChange`

### Deprecated (to be removed in SDK 11):

* `notificationRegistrationFinishedWithOptions:categories:`
* `notificationAuthorizedOptionsDidChange:`

## UAPush

UAPush properties and methods have also been updated to reflect the new authorization model, and iOS 8
workarounds have been removed.

### Added

* `authorizationStatus`
* `enableUserPushNotifications:completionHandler`

### Deprecated (to be removed in SDK 11)

* `authorizedNotificationOptions`

### Removed (iOS 8 workarounds)

* `allowUnregisteringUserNotificationTypes`
* `requireSettingsAppToDisableUserNotifications`

### Removed (previously deprecated)

* `alias`

## UANotificationCategory

Additional properties and factory methods have been added to support custom category summary formats, as well as placeholder strings for
notifications with hidden body previews.

### Added

* `categorySummaryFormat`
* `categorywithIdentifier:actions:intentIdentifiers:hiddenBodyPreviewsPlaceholder:categorySummaryFormat:options:`

## UANotificationContent

Additional properties have been added to support the summary argument, summary argument count and thread ID features new to iOS 12.

### Added

* `summaryArgument`
* `summaryArgumentCount`
* `threadIdentifier`

## UAJSONMatcher

### Removed (previously deprecated)

* `matcherWithValueMatcher:key`
* `matcherWithValueMatcher:key:scope`

The methods above are redundant, and have been replaced with the more general `matcherWithValueMatcher:scope`.
The removed `key` parameter is just the last value of a scope array, so for instance, calls such as

```objective-c
[UAJSONMatcher matcherWithValueMatcher:someValueMatcher key:@"key"]
```
```objective-c
[UAJSONMatcher matcherWithValueMatcher:someValueMatcher key:@"key" scope:@[@"foo", @"bar"]]
```
can be rewritten as the following, respectively:

```objective-c
[UAJSONMatcher matcherWithValueMatcher:someValueMatcher scope:@[@"key"]]
```
```objective-c
[UAJSONMatcher matcherWithValueMatcher:someValueMatcher scope:@[@"foo", @"bar", @"key"]]
```

## UAInboxDelegate

### Removed (previously deprecated)

* `showInboxMessage:`

## UAMessageCenterMessageViewProtocol

### Removed (previously deprecated)

* `loadMessage:onlyIfChanged:`

***See [legacy migration guide](Migration%20Guide%20(Legacy).md) for older migrations***
