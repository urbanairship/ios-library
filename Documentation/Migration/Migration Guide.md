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
* `	categorywithIdentifier:actions:intentIdentifiers:hiddenBodyPreviewsPlaceholder:categorySummaryFormat:options:`

## UANotificationContent

Additional properties have been added to support the summary argument, summary argument count and thread ID features new to iOS 12.

### Added

* `summaryArgument`
* `summaryArgumentCount`
* `threadIdentifier`

# Urban Airship Library 8.x to 9.0

## Automation

UAAutomation has been generalized, and now works with UASchedule objects. Most of the methods have been renamed to reflect this:

* `(void)scheduleActions:(UAActionScheduleInfo *)scheduleInfo completionHandler:(nullable void (^)(UAActionSchedule * __nullable))completionHandler` -> `(void)scheduleActions:(UAActionScheduleInfo *)scheduleInfo completionHandler:(nullable void (^)(UASchedule * __nullable))completionHandler`
* `(void)cancelScheduleWithIdentifier:(NSString *)identifier` -> `(void)cancelScheduleWithID:(NSString *)identifier`
* `(void)getScheduleWithIdentifier:(NSString *)identifier completionHandler:(void (^)(UAActionSchedule * __nullable))completionHandler` -> `(void)getScheduleWithID:(NSString *)identifier completionHandler:(void (^)(UASchedule * __nullable))completionHandler`
* `(void)getSchedules:(void (^)(NSArray<UAActionSchedule *> *))completionHandler` -> `(void)getSchedules:(void (^)(NSArray<UASchedule *> *))completionHandler`
* `(void)getSchedulesWithGroup:(NSString *)group completionHandler:(void (^)(NSArray<UAActionSchedule *> *))completionHandler` -> `(void)getSchedulesWithGroup:(NSString *)group completionHandler:(void (^)(NSArray<UASchedule *> *))completionHandler`

UAScheduleDelay now supports multiple screens:

* const: `UAScheduleDelayScreenKey` -> `UAScheduleDelayScreensKey`
* property: `NSString *screen` -> `NSArray *screens`

## In App Messaging
Urban Airship's banner-only In-App Messaging feature has been replaced with a more functional In-App Messaging feature that supports banner, modal and full screen messages. Please refer to [In-App Messaging for iOS](https://docs.urbanairship.com/guides/ios-in-app-messaging/) for more information.

## Message Center
UIWebView support has been removed from the UA Message Center. Other Message Center code has been renamed or removed. The changes are as follows:

### Renamed
#### Classes
* UADefaultMessageCenter* -> UAMessageCenter*
    * [UADefaultMessageCenter](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenter.html) -> [UAMessageCenter](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenter.html)
    * [UADefaultMessageCenterListCell](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenterListCell.html) -> [UAMessageCenterListCell](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenterListCell.html)
    * [UADefaultMessageCenterListViewController](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenterListViewController.html) -> [UAMessageCenterListViewController](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenterListViewController.html)
    * [UADefaultMessageCenterSplitViewController](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenterSplitViewController.html) -> [UAMessageCenterSplitViewController](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenterSplitViewController.html)
    * [UADefaultMessageCenterStyle](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenterStyle.html) -> [UAMessageCenterStyle](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenterStyle.html)

#### Properties
* [UAirship](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAirship.html)
    * defaultMessageCenter -> messageCenter

### Removed
#### Classes
* [UALandingPageOverlayController](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UALandingPageOverlayController.html)
    * Use [UAOverlayViewController](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAOverlayViewController.html)
* [UADefaultMessageCenterMessageViewController](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenterMessageViewController.html)
    * Use [UAMessageCenterMessageViewController](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenterMessageViewController.html)
* [UARichContentWindow](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Protocols/UARichContentWindow.html), UAUIWebViewDelegate
    * Use [UAWKWebViewDelegate](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAWKWebViewDelegate.html)
* UAWebViewDelegate
    * Use [UAWKWebViewNativeBridge](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAWKWebViewNativeBridge.html)

#### Methods and Properties
 * [UAConfig](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAConfig.html)
    * [useWKWebView](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UAConfig.html#/c:objc(cs)UAConfig(py)useWKWebView)
        * No replacement. WKWebViews are now always used in inbox message and overlay views.
 * [UAMessageCenter](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenter.html) (UADefaultMessageCenter)
    * [displayMessage:](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenter.html#/c:objc(cs)UADefaultMessageCenter(im)displayMessage:)
        * Use [displayMessageForID:](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenter.html#/c:objc(cs)UAMessageCenter(im)displayMessageForID:)
    * [displayMessage:animated](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenter.html#/c:objc(cs)UADefaultMessageCenter(im)displayMessage:animated:)
        * Use [displayMessageForID:animated:](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenter.html#/c:objc(cs)UAMessageCenter(im)displayMessageForID:animated:)
* [UAMessageCenterListViewController](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenterListViewController.html) (UADefaultMessageCenterListViewController)
    * [displayMessage:](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenterListViewController.html#/c:objc(cs)UAMessageCenterListViewController(im)displayMessage:)
        * Use [displayMessageForID:](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenterListViewController.html#/c:objc(cs)UAMessageCenterListViewController(im)displayMessageForID:)
    * [displayMessage:onError:](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UADefaultMessageCenterListViewController.html#/c:objc(cs)UADefaultMessageCenterListViewController(im)displayMessage:onError:)
        * Use [displayMessageForID:onError:](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAMessageCenterListViewController.html#/c:objc(cs)UAMessageCenterListViewController(im)displayMessageForID:onError:)
* [NSString+UAURLEncoding](https://docs.urbanairship.com/reference/libraries/ios/latest/Categories/NSString(UAURLEncoding).html)
    * [urlDecodedStringWithEncoding:](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Categories/NSString(UAURLEncoding).html#/c:objc(cs)NSString(im)urlDecodedStringWithEncoding:)
        * Use [urlDecodedString](https://docs.urbanairship.com/reference/libraries/ios/latest/Categories/NSString(UAURLEncoding).html#/c:objc(cs)NSString(im)urlDecodedString)
    * [urlEncodedStringWithEncoding:](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Categories/NSString(UAURLEncoding).html#/c:objc(cs)NSString(im)urlEncodedStringWithEncoding:)
        * Use [urlEncodedString](https://docs.urbanairship.com/reference/libraries/ios/latest/Categories/NSString(UAURLEncoding).html#/c:objc(cs)NSString(im)urlEncodedString)
* [UAWebViewCallData](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAWebViewCallData.html)
    * [callDataForURL:webView:](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UAWebViewCallData.html#/c:objc(cs)UAWebViewCallData(cm)callDataForURL:webView:)
        * Use [callDataForURL:delegate](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAWebViewCallData.html#/c:objc(cs)UAWebViewCallData(cm)callDataForURL:delegate:)
    * [callDataForURL:webView:message](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UAWebViewCallData.html#/c:objc(cs)UAWebViewCallData(cm)callDataForURL:webView:message:)
        * Use [callDataForURL:delegate:message](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAWebViewCallData.html#/c:objc(cs)UAWebViewCallData(cm)callDataForURL:delegate:message:)
    * [webView](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UAWebViewCallData.html#/c:objc(cs)UAWebViewCallData(py)webView)
        * No replacement
    * [richContentWindow](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Classes/UAWebViewCallData.html#/c:objc(cs)UAWebViewCallData(py)richContentWindow)
        * No replacement

### Other
* [UAActionJSDelegate](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes.html#/c:objc(cs)UAActionJSDelegate)
    * [UAActionMetadataWebViewKey](https://docs.urbanairship.com/reference/libraries/ios/8.6.0/Constants.html#/c:@UAActionMetadataWebViewKey)
        * No replacement - no longer supported

***See [legacy migration guide](Migration%20Guide%20(Legacy).md) for older migrations***
