# Urban Airship iOS SDK Migration Guide

# Urban Airship Library 9.x to 10.0

This is a compatibility release for iOS 12 support, mostly adding new optional features. However some breaking changes have been made
in order to suppport them. Since iOS 8 is no longer supported, some iOS 8 specific workarounds have been removed, as well as items previously 
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

## UAInboxDelegate

### Removed (previously deprecated)

* `showInboxMessage:`

## UAMessageCenterMessageViewProtocol

### Removed (previously deprecated)

* `loadMessage:onlyIfChanged:`

***See [legacy migration guide](Migration%20Guide%20(Legacy).md) for older migrations***
