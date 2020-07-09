# Airship iOS SDK Migration Guide

# Airship Library 9.x to 10.0

This is a compatibility release for iOS 12 support, mostly adding new optional features. However some breaking changes have been made
in order to support them.

Items previously marked "Deprecated - to be removed in SDK version 10.0" have been removed. Some iOS 8 specific workarounds that
have been obsolete since SDK 9.0 have also been removed. This release also drops support for iOS 9.

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

***See [legacy migration guide](migration-guide-legacy.md) for older migrations***
