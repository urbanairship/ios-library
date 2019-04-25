# Airship iOS SDK Migration Guide (Legacy)

***See [current migration guide](Migration%20Guide.md) for more recent migrations***

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

# Urban Airship Library 8.x to 8.3.0
## WKWebView Support
Version 8.3.0 adds support for iOS's [WKWebView](https://developer.apple.com/reference/webkit/wkwebview). UIWebView support for Urban Airship's default message center and overlay views will be removed in iOS SDK 9.0.
### [useWKWebView](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAConfig.html#/c:objc(cs)UAConfig(py)useWKWebView) key
By including the "useWKWebView" key in AirshipConfig.plist and setting the value to "YES", you can enable WKWebView support for messages in the default message center ([UADefaultMessageCenter](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UADefaultMessageCenter.html)) and for landing pages ([UALandingPageOverlayController﻿](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UALandingPageOverlayController.html)).
### [UAWKWebViewNativeBridge](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAWKWebViewNativeBridge.html)
UAWKWebViewNativeBridge is the interface for integrating Urban Airship features into your own WKWebViews. Please see the [iOS Message Center Customization Topic Guide](https://docs.urbanairship.com/topic-guides/ios-message-center-customization.html) or the [Custom Events Guide](https://docs.urbanairship.com/guides/custom-events/) for more information
### Scaling differences
WKWebView by default scales the content to fit the view. This is different than UIWebView. The following is an example of the rendering of simple message center message with a body containing only an image tag: `<img src="https://www.urbanairship.com/images/urban-airship-sidebyside-blue@2x.png">`

WKWebView | UIWebView
--- | ---
<div style="text-align:center"><img src="images/wkwebview-simple-message.png" style="border:3px solid black"></div> | <div style="text-align:center"><img src="images/uiwebview-simple-message.png" style="border:3px solid black"></div>

Fully styled content, such as that contained in messages created in the [Rich Content Editor](https://docs.urbanairship.com/engage/rich-content-editor/) of the Message Composer, will render identically using either type of web view.

## Application Integration

A new application integration point has been added to [UAAppIntegration](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes.html#/c:objc(cs)UAAppIntegration).
If your application disables automatic integration, it will need to be updated to call
the new method:

### UIApplicationDelegate method:

#### Swift
```swift
func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error)
``` 

#### Objective-C
```objective-c
+ (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
``` 

# Urban Airship Library 7.3.0 to 8.0.0

This version supports iOS 8, 9 and 10. Xcode 8 is required.

With iOS 10 and SDK 8 you have the ability to send Rich Notifications. To configure rich notification support, please visit [iOS Notification Service Extensions](https://docs.urbanairship.com/platform/ios/#notification-service-extension).

## Application Integration

All application integration points have been moved to [UAAppIntegration](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes.html#/c:objc(cs)UAAppIntegration).
If your application disables automatic integration, it will need to be updated to call
the new methods:

### UIApplicationDelegate methods:

#### Swift
```swift
func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData)

func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void)

func application(application: UIApplication, didRegisterUserNotificationSettings notificationSettings: UIUserNotificationSettings)

func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [NSObject : AnyObject], completionHandler: () -> Void)

func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [NSObject : AnyObject], withResponseInfo responseInfo: [NSObject : AnyObject], completionHandler: () -> Void)
``` 

#### Objective-C
```objective-c
+ (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;

+ (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

+ (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;

+ (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())handler;

+ (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo withResponseInfo:(nullable NSDictionary *)responseInfo completionHandler:(void (^)())handler;
``` 

### UNUserNotificationDelegate methods:

#### Swift
```swift
func userNotificationCenter(center: UNUserNotificationCenter, didReceiveNotificationResponse response: UNNotificationResponse, withCompletionHandler completionHandler: () -> Void)

func userNotificationCenter(center: UNUserNotificationCenter, willPresentNotification notification: UNNotification, withCompletionHandler completionHandler: (_ options: UNNotificationPresentationOptions) -> Void)
``` 

#### Objective-C
```objective-c
+ (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void(^)())completionHandler;

+ (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler;
``` 

## UAPush

The property `launchNotification` has been replaced with `launchNotificationResponse`
and will contain a `UANotificationResponse`.

Notification categories and types have been removed. Instead you can set UANotificationOptions
and UANotificationCategory and the SDK will automatically convert the properties to the
appropriate types depending on the OS version.

```swift
// Old
func currentEnabledNotificationTypes() -> UIUserNotificationType
var userNotificationTypes: UIUserNotificationType
var userNotificationCategories = Set<NSObject>()

// New
var notificationOptions: UANotificationOptions
var authorizedNotificationOptions: UANotificationOptions
var customCategories: Set<UANotificationCategory>
``` 

```objective-c
// Old
- (UIUserNotificationType)currentEnabledNotificationTypes;
@property (nonatomic, assign) UIUserNotificationType userNotificationTypes;
@property (nonatomic, strong) NSSet *userNotificationCategories;

// New
@property (nonatomic, assign) UANotificationOptions notificationOptions;
@property (nonatomic, assign, readonly) UANotificationOptions authorizedNotificationOptions;
@property (nonatomic, strong) NSSet <UANotificationCategory *>customCategories;
``` 

## UAPushNotificationDelegate

The UAPushNotificationDelegate has been rewritten to be more aligned with iOS 10.
The following methods are provided:

```swift
func receivedForegroundNotification(_ notificationContent: UANotificationContent, completionHandler: () -> Void)
func receivedBackgroundNotification(_ notificationContent: UANotificationContent, completionHandler: (UIBackgroundFetchResult) -> Void)
func receivedNotificationResponse(_ notificationResponse: UANotificationResponse, completionHandler: () -> Void)
func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions
``` 

```objective-c
-(void)receivedForegroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)())completionHandler;
-(void)receivedBackgroundNotification:(UANotificationContent *)notificationContent completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
-(void)receivedNotificationResponse:(UANotificationResponse *)notificationResponse completionHandler:(void (^)())completionHandler;
- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification;
``` 

## UAUtils

The `isBackgroundPush` method has been replaced with `isSilentPush`.

# Urban Airship Library 7.2.x to 7.3.0

## Named User

[UANamedUser](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes.html#/c:objc(cs)UANamedUser) access has been moved to [UAirship](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes.html#/c:objc(cs)UAirship).

Added

```swift
UAirship.namedUser().identifier = "NamedUserID"
``` 

```objective-c
[UAirship namedUser].identifier = @"NamedUserID";
``` 

Deprecated

```swift
UAirship.push().namedUser.identifier = "NamedUserID"
``` 

```objective-c
[UAirship push].namedUser.identifier = @"NamedUserID";
``` 

## Location Service

[UALocationService](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes.html#/c:objc(cs)UALocationService) and [UALocationServiceDelegate](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes.html#/c:objc(cs)UALocationServiceDelegate) has been deprecated and
replaced with [UALocation](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes.html#/c:objc(cs)UALocation) and [UALocationDelegate](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes.html#/c:objc(cs)UALocationDelegate). See [iOS Platform Guide](https://docs.urbanairship.com/platform/ios#ios-location) on
how to use the new location APIs.

# Urban Airship Library 7.0.0 to 7.2.x

## Wallet Action

The Urban Airship library no longer references the Passkit framework for the wallet action.
This is to work around the App Store incorrectly showing an app "Supports Wallet"
when it does not contain wallet capabilities (Radar #24942020). The wallet action
now behaves exactly like the open URL external action. If the old wallet action
behavior is desired, please see [Apple Wallet extension](https://github.com/urbanairship/ua-extensions/tree/master/AppleWallet).

# Urban Airship Library 6.1.x to 7.0.0

Anything deprecated in 6.x.x or older has been removed from the library in 7.0.0. This version also hides undocumented APIs.

## Package Changes

The AirshipResources bundle stores resources necessary for the Message Center and other Urban Airship library features. For details on integrating the
AirshipResources bundle, see the [iOS Platform Guide](https://docs.urbanairship.com/platform/ios#platform-ios).

## Message Center

Applications that make use of previous iterations of the Urban Airship Message Center will be required to implement the UAInboxDelegate. Implementing the UAInboxDelegate is necessary to ensure the correct Message Center is displayed upon message receipt. For more information regarding Message Center integration, see the [Message Center Integration Guide](https://docs.urbanairship.com/platform/ios#ios-rich-push).

# Urban Airship Library 6.0.x to 6.1.x

## AirshipKit

Urban Airship 6.1 brings changes to the way the AirshipKit framework
is distributed and embedded. Instead of shipping a pre-built universal
binary, AirshipKit is now distributed as an Xcode project, which you
can drag into your application so that the framework is built and
embedded in your app at compile time. For detailed information on
embedding AirshipKit, see the [SDK setup instructions](https://docs.urbanairship.com/platform/ios#sdk-installation).

## UAInboxPushHandlerDelegate

The UAInboxPushHandlerDelegate has been deprecated for the new, simplified delegate UAInboxDelegate. The UAInboxDelegate can be set directly on
the inbox:

```objective-c
[UAirship inbox].delegate = self.inboxDelegate;
``` 

Once the inbox delegate is set, the UAInboxPushHandlerDelegate will no longer be called.

The UAInboxDelegate is not a direct replacement for UAInboxPushHandlerDelegate. It only defines a subset of
the methods that UAInboxPushHandlerDelegate defined. `showInboxMessage:` will be called instead of `launchRichPushMessageAvailable:`. Neither
`applicationLaunchedWithRichPushNotification:` nor `richPushNotificationArrived:` have corresponding methods. Instead,
look for a message ID in incoming notifications in the UAPushNotificationDelegate:

```objective-c
- (void)receivedForegroundNotification:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {

    // Inbox message associated with the received notification
    if ([UAInboxUtils inboxMessageIDFromNotification:notification]) {

    }

    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)launchedFromNotification:(NSDictionary *)notification fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // Inbox message associated with the received notification
    if ([UAInboxUtils inboxMessageIDFromNotification:notification]) {

    }

    // Call the completion handler
    completionHandler(UIBackgroundFetchResultNoData);
}
``` 

The UAInboxDelegate only requires `showInbox` method, `richPushMessageAvailable:` and `showInboxMessage:` are optional.
If both the  UAInboxPushHandlerDelegate and the UAInboxDelegate delegate are not set, or if UAInboxDelegate does not respond
to `showInboxMessage:`, the message will be displayed in a landing page controller.

## Device-side Tags

> The UAPush property `deviceTagsEnabled` has been deprecated and replaced
> with `channelTagRegistrationEnabled`.

# Urban Airship Library 5.1.x to 6.0.x

Anything deprecated in 5.x.x or older has been removed from the library in 6.0.0.

## Disabling User Notifications

<!-- start_ios-disabling-user-notifications -->
By default, user push notifications may now only be enabled from within applications running
on iOS 8+. Once user notifications are enabled and a user has been prompted for permission,
the setting may not be changed from within the app. We now recommend that applications
running on iOS 8 link directly to the system push settings for the application with the
`UIApplicationOpenSettingsURLString` constant.

```objective-c
// Launch directly to your applications settings in Settings.app
[[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
``` 

<!-- end_ios-disabling-user-notifications -->
A few changes were made to `UAPush` to support this. A new property,
`requireSettingsAppToDisableUserNotifications` (defaulting to `YES`), is used
to determine whether or not to allow `userPushNotificationsEnabled` to change from `YES`
to `NO`. Its companion property, `allowUnregisteringUserNotificationTypes` now defaults to `YES`,
which will allow the application to disable user notifications at the iOS level to keep
the application settings  in sync with the iOS settings screen.

## Singleton Accessors

All of the singleton accessors, except for `[UAirship shared]` have been deprecated. New accessors
are available through class methods or properties off of `UAirship`. Any accessor will now return
nil instead of an uninitialized object until takeOff is called.

Changes:

* `[UAPush shared]` moved to `[UAirship push]`

* `[UAInbox shared]` moved to `[UAirship inbox]`

* `[UAUser defaultUser]` moved to `[UAirship inboxUser]`

* `[UAActionRegistry shared]` moved to `[UAirship shared].actionRegistry`

## UAirship

The device token access has been removed. Instead, use [UAirship deviceToken](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAirship.html#/c:objc(cs)UAirship(py)deviceToken).

Removed

```objective-c
@property (nonatomic, readonly) NSString *deviceToken;
``` 

## UAAction

The `performWithArguments:actionName:completionHandler:` method has been deprecated and replaced
by `performWithArguments:completionHandler:`. If the action was triggered by name from the action
registry, the name of the action can be found in the ActionArguments' metadata under the key
`UAActionMetadataRegisteredName`.

Example:

```objective-c
- (void)performWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler {
    NSString *actionName = arguments.metadata[UAActionMetadataRegisteredName];
}
``` 

Added

```objective-c
- (void)performWithArguments:(UAActionArguments *)arguments completionHandler:(UAActionCompletionHandler)completionHandler;
``` 

Deprecated

```objective-c
- (void)performWithArguments:(UAActionArguments *)arguments actionName:(NSString *)name completionHandler:(UAActionCompletionHandler)completionHandler;
``` 

## UAActionRunner

The action runner no longer accepts `UAActionArguments`, instead it accepts the argument's situation, metadata, and value.
The action arguments will then be constructed internally and passed to the action.

Added

```objective-c
+ (void)runActionWithName:(NSString *)actionName
                    value:(id)value
                situation:(UASituation)situation;

+ (void)runActionWithName:(NSString *)actionName
                    value:(id)value
                situation:(UASituation)situation
                 metadata:(NSDictionary *)metadata;

+ (void)runActionWithName:(NSString *)actionName
                    value:(id)value
                situation:(UASituation)situation
        completionHandler:(UAActionCompletionHandler)completionHandler;

+ (void)runActionWithName:(NSString *)actionName
                value:(id)value
            situation:(UASituation)situation
             metadata:(NSDictionary *)metadata
    completionHandler:(UAActionCompletionHandler)completionHandler;

+ (void)runAction:(UAAction *)action
            value:(id)value
        situation:(UASituation)situation;

+ (void)runAction:(UAAction *)action
            value:(id)value
        situation:(UASituation)situation
         metadata:(NSDictionary *)metadata;

+ (void)runAction:(UAAction *)action
            value:(id)value
        situation:(UASituation)situation
completionHandler:(UAActionCompletionHandler)completionHandler;

+ (void)runAction:(UAAction *)action
            value:(id)value
        situation:(UASituation)situation
         metadata:(NSDictionary *)metadata
completionHandler:(UAActionCompletionHandler)completionHandler;
``` 

Removed

```objective-c
+ (void)runActionWithName:(NSString *)actionName
                withArguments:(UAActionArguments *)arguments
        withCompletionHandler:(UAActionCompletionHandler)completionHandler;

+ (void)runAction:(UAAction *)action
    withArguments:(UAActionArguments *)arguments
withCompletionHandler:(UAActionCompletionHandler)completionHandler;

+ (void)runActions:(NSDictionary *)actions
 withCompletionHandler:(UAActionCompletionHandler)completionHandler;
``` 

## UAActionArguments

`UASituationForegoundInteractiveButton` has been deprecated and replaced with `UASituationForegroundInteractiveButton`.

## UAInboxPushHandlerDelegate

Two required methods have been added - `showInbox` and `showInboxMessage:`. These methods are needed
to allow the SDK to directly link to the inbox or an inbox message.

Added

```objective-c
- (void)showInbox;
- (void)showInboxMessage:(UAInboxMessage *)inboxMessage;
``` 

## UAInboxUtils

The methods `getRichPushMessageIDFromNotification:` and `getRichPushMessageIDFromValue:` have been renamed to
`inboxMessageIDFromNotification:` and `inboxMessageIDFromValue`.

Added

```objective-c
+ (NSString *)inboxMessageIDFromNotification:(NSDictionary *)notification;
+ (NSString *)inboxMessageIDFromValue:(id)values;
``` 

Removed

```objective-c
+ (NSString *)getRichPushMessageIDFromNotification:(NSDictionary *)notification;
+ (NSString *)getRichPushMessageIDFromValue:(id)richPushValues;
``` 

## Normalized naming

Updated the library with normalized naming of `Id` and `id` to `ID`.

# Urban Airship Library 5.0.x to 5.1.x

## Whitelisting

Added whitelisting to Urban Airship JavaScript interface injection into custom webview implementations. Urban Airship URLs are automatically whitelisted, but if the UA JavaScript bridge is used outside of Urban Airship hosted Rich Application Pages, the hosting URLs need to be whitelisted.

Whitelist rules can be defined in the AirshipConfig.plist file by defining an array of rules, or directly on the whitelist instance after `takeOff`:

```objective-c
[[UAirship shared].whitelist addEntry:@"https://urbanairship.com"];
``` 

See [Whitelist](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAWhitelist.html) for more details on creating valid URL patterns.

## Urban Airship JavaScript Interface

In order to use the Urban Airship JavaScript interface on a custom webview implementation, you must use the new UAWebViewDelegate. Previous methods of injecting the Urban Airship JavaScript are now deprecated.

The UAWebViewDelegate can be subclassed, called through to by other UIWebViewDelegates, or it can forward all UIWebViewDelegate messages to a different delegate by assigning the `forwardDelegate` on the UAWebViewDelegate instance.

The `UAWebViewTools` interface has been deprecated in 5.1.0 and replaced with custom webview implementations using the `UAWebViewDelegate` class:

```objective-c
@interface UAWebViewTools : NSObject
``` 

The following `UIWebView+UAAdditions` methods have been deprecated in 5.1.0:

```objective-c
- (void)populateJavascriptEnvironment:(UAInboxMessage *)message
- (void)populateJavascriptEnvironment
- (void)fireUALibraryReadyEvent
``` 

The following `UIWebView+UAAdditions` method has been added in 5.1.0:

```objective-c
- (void)injectInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
``` 

The `UAWebViewDelegate` interface and its properties have been added in 5.1.0:

```objective-c
@interface UAWebViewDelegate : NSObject <UIWebViewDelegate>
@property (nonatomic, weak) id <UIWebViewDelegate> forwardDelegate;
@property (nonatomic, weak) id <UARichContentWindow> richContentWindow;
``` 

The `closeWindow` method in `UARichContentWindow` has been deprecated in 5.1.0 and replaced with `closeWebView:animated:`.

Deprecated in 5.1.0:

```objective-c
- (void)closeWindow:(BOOL)animated;
``` 

Added in 5.1.0:

```objective-c
- (void)closeWebView:(UIWebView *)webView animated:(BOOL)animated;
``` 

# Urban Airship Library 4.x to 5.0.0

This version supports iOS 6, 7 and 8. Xcode 6 is required for all projects and the static library.

## UAPush Changes

UAPush has significantly changed to support iOS 8.

### Registration Changes

The `pushEnabled` property has been removed and replaced with `userPushNotificationsEnabled`
The default value for `userPushNotificationsEnabled` is `NO` and can be set
with `userPushNotificationsEnabledByDefault`.

The `[UAPush delegate]` property deprecated in 3.0.0 has been removed and replaced with
`[UAPush pushNotificationDelegate]`.

The `addTagToCurrentDevice`, `addTagsToCurrentDevice`, `removeTagFromCurrentDevice`
and `removeTagsFromCurrentDevice` methods have been deprecated and replaced with
`addTag`, `addTags`, `removeTag` and `removeTags` methods, respectively.

The `registerForRemoteNotificationTypes` and `registerForRemoteNotifications`
methods have been removed, so the `updateRegistration` method should be called
instead. The `UIRemoteNotificationType notificationTypes` property has been
deprecated and replaced with `UIUserNotificationType userNotificationTypes`.

The `currentEnabledNotificationTypes` method has been changed from a class
method to an instance method and now returns a `UIUserNotificationType` enum.

The `setQuietTimeFrom:to:withTimeZone:` method deprecated in 3.2.0 has been
removed and replaced with `setQuietTimeStartHour:startMinute:endHour:endMinute:`.

The `backgroundPushNotificationsEnabled` property has been added to enable/disable
background remote notifications on the device through Urban Airship. The default
value for `backgroundPushNotificationsEnabled` is `YES` and can be set with
`backgroundPushNotificationsEnabledByDefault`.

Removed in 5.0.0:

```objective-c
@property (nonatomic) BOOL pushEnabled;
@property (nonatomic, weak) id<UAPushNotificationDelegate> delegate;

- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types;
- (void)registerForRemoteNotifications;
- (void)setQuietTimeFrom:(NSDate *)from to:(NSDate *)to withTimeZone:(NSTimeZone *)tz;
``` 

Deprecated in 5.0.0:

```objective-c
@property (nonatomic, assign) UIRemoteNotificationType notificationTypes;

- (void)addTagToCurrentDevice:(NSString *)tag
- (void)addTagsToCurrentDevice:(NSArray *)tags
- (void)removeTagFromCurrentDevice:(NSString *)tag
- (void)removeTagsFromCurrentDevice:(NSArray *)tags
``` 

Added in 5.0.0:

```objective-c
@property (nonatomic, assign) UIUserNotificationType userNotificationTypes;
@property (nonatomic, assign) BOOL userPushNotificationsEnabled;
@property (nonatomic, assign) BOOL userPushNotificationsEnabledByDefault;
@property (nonatomic, assign) BOOL backgroundPushNotificationsEnabled;
@property (nonatomic, assign) BOOL backgroundPushNotificationsEnabledByDefault;
@property (nonatomic, strong) NSSet *userNotificationCategories;
@property (nonatomic, assign) BOOL requireAuthorizationForDefaultCategories;

- (void)addTag:(NSString *)tag;
- (void)addTags:(NSArray *)tags;
- (void)removeTag:(NSString *)tag;
- (void)removeTags:(NSArray *)tags;
``` 

### App Delegate Changes

If automatic integration is enabled, then no changes are needed and this section
can be ignored.

The `registerDeviceToken` method as been removed and replaced with
`appRegisteredForRemoteNotificationsWithDeviceToken`.

The `handleNotification` methods have been removed and replaced with the
`appReceivedRemoteNotification` methods.

Removed in 5.0.0:

```objective-c
- (void)registerDeviceToken:(NSData *)token;
- (void)handleNotification:(NSDictionary *)notification applicationState:(UIApplicationState)state;
- (void)handleNotification:(NSDictionary *)notification
          applicationState:(UIApplicationState)state
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;
``` 

Added 5.0.0:

```objective-c
- (void)appRegisteredForRemoteNotificationsWithDeviceToken:(NSData *)token;
- (void)appReceivedRemoteNotification:(NSDictionary *)notification
                     applicationState:(UIApplicationState)state;
- (void)appReceivedRemoteNotification:(NSDictionary *)notification
                     applicationState:(UIApplicationState)state
               fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;
- (void)appReceivedActionWithIdentifier:(NSString *)identifier
                           notification:(NSDictionary *)notification
                       applicationState:(UIApplicationState)state
                      completionHandler:(void (^)())completionHandler;
``` 

## UAConfig Changes

The `clearKeychain` property has been deprecated as of version 5.0.0. To clear the
keychain once during the next application start, use the settings bundle to set
`YES` for the key `com.urbanairship.reset_keychain` in standard user defaults.

Property deprecated:

```objective-c
@property (nonatomic, assign) BOOL clearKeychain;
``` 

## UAObservable Changes

The `UAObservable` interface and all related protocols/methods deprecated in
version 3.0.0 has been removed. They have been replaced with three categories:
block-based methods, delegate-based methods, and NSNotificationCenter events.

Interface removed in 5.0.0:

```objective-c
@interface UAObservable : NSObject;
``` 

## UALocationService Changes

A `requestAlwaysAuthorization` property has been added as of version 5.0.0. This property
allows the location prompt authorization type to be selected. When `requestAlwaysAuthorization`
is set to YES - users will be prompted to grant continuous background authorization.
When `requestAlwaysAuthorization` is set to NO - users will be prompted to grant 'when in
use' authorization. The `requestAlwaysAuthorization` property is set to YES by default
because continuous background authorization is required for some UALocationService features.
Care must be taken in selecting the correct authorization type, as the authorization prompt
will only display once per app update.

NSLocationAlwaysUsageDescription and NSLocationWhenInUseUsageDescription must be defined
in the app's info.plist for authorization prompts to display.

Property added:

```objective-c
@property (nonatomic, assign) BOOL requestAlwaysAuthorization;
``` 

## Localization Changes

As of version 5.0.0, the `UAPushLocalization.bundle` and
`UAInboxLocalization.bundle` files have been removed. In their place,
the Push and Rich Push sample UI now search for localized strings in
the main bundle, in tables named `UAPushUI.strings` and
`UAInboxUI.strings` respectively. These are located in the
directories `Airship/UI/Default/Push/Resources` and
`Airship/UI/Default/Inbox/Resources`.

Consequently, the `UA_PU_TR` and `UA_Inbox_TR` macros, previously
used by the sample UI, have been modified and renamed. Instead, use
the new `UAPushLocalizedString` and `UAInboxLocalizedString`
macros, defined in the headers `UAInboxLocalization.h` and
`UAPushLocalization.h`, respectively. These headers are found in the
directories `Airship/UI/Default/Push/Classes` and
`Airship/UI/Default/Inbox/Classes`.

## Push UI Changes

The `UAPushUIProtocol` has been removed in 5.0.0:

```objective-c
@protocol UAPushUIProtocol
+ (void)openApnsSettings:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)closeApnsSettingsAnimated:(BOOL)animated;
+ (void)openTokenSettings:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)closeTokenSettingsAnimated:(BOOL)animated;
``` 

Consequently, similar methods corresponding to this protocol in `UAPush` have also been
removed in 5.0.0:

```objective-c
+ (void)useCustomUI:(Class)customUIClass;
+ (void)openApnsSettings:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)closeApnsSettingsAnimated:(BOOL)animated;
+ (void)openTokenSettings:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)closeTokenSettingsAnimated:(BOOL)animated;
``` 

In place of `UAPushUIProtocol`, your app should simply create and display UI class
instances directly, in response to user interaction. For instance, if your app is
using the sample UI classes distributed with the library, the classes corresponding
to the APNS and Token settings are `UAPushSettingsViewController` and
`UAPushMoreSettingsViewController`, respectively. For a simple example implementation,
see the PushSample project distributed with the library.

## UAAction Changes

The `performWithArguments` method has been modified in 5.0.0 to require an actionName `(NSString *)` value.

The following method has been removed as of 5.0.0 and replaced with `performWithArguments:actionName:completionHandler:`:

```objective-c
- (void)performWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler;
``` 

Added method in 5.0.0:

```objective-c
- (void)performWithArguments:(UAActionArguments *)arguments
                  actionName:(NSString *)name
           completionHandler:(UAActionCompletionHandler)completionHandler;
``` 

## Inbox UI Changes

The `UAInboxUIProtocol` has been removed in 5.0.0:

```objective-c
@protocol UAInboxUIProtocol
+ (void)quitInbox;
+ (void)displayInboxInViewController:(UIViewController *)parentViewController animated:(BOOL)animated;
+ (void)displayMessageWithID:(NSString *)messageID inViewController:(UIViewController *)parentViewController;
``` 

As with the the `UAPushUIProtocol` removal discussed above, related methods have
also been removed from `UAInbox`:

```objective-c
- (Class)uiClass;
+ (void)useCustomUI:(Class)customUIClass;
+ (void)quitInbox;
+ (void)displayInboxInViewController:(UIViewController *)parentViewController animated:(BOOL)animated;
+ (void)displayMessageWithID:(NSString *)messageID inViewController:(UIViewController *)parentViewController;
``` 

Additionally, in the sample UI, the classes `UAInboxUI` and `UAInboxNavUI` have
also been removed, as they primarily served as reference implementation of the above
protocol. As these classes also implemented the `UAInboxPushHandlerDelegate`
protocol, apps using the sample UI more or less unchanged will need to implement
`UAInboxPushHandlerDelegate` elsewhere, such as the app delegate or primary
view controller.

In place of the `UAInboxUI` protocol, your app should instead instantiate and display
instances of the appropriate UI classes directly. In practice, these changes result in code
that is much easier to follow than the previous arrangement, due to a reduction in
circularity and a better separation of concerns.

For instance, if your app is using the supplied sample UI classes distributed with
the library, displaying the inbox in a modal view controller is as straightfoward
as configuring an instance of `UAInboxMessageListController`, setting it as the root
of a `UINavigationController` instance, and then calling the
`presentViewController:animated` method on the desired parent view controller.

As before, see the supplied `RichPushSample` app for a basic implementation that
demonstrates multiple user interface approaches with modal display, navigation
controller embedding, and a popover interface for iPad.

## UAInboxMessageList Changes

The `UAInboxMessageListDelegate` protocol has been deprecated as of 5.0.0. Use
the block based message list callbacks instead.

```objective-c
@protocol UAInboxMessageListDelegate <NSObject>
``` 

The UAInboxMessageList shared singleton accessor deprecated in 3.1.0 has been
removed and replaced with `[UAInbox shared].messageList`:

```objective-c
+ (UAInboxMessageList *)shared;
``` 

The following methods deprecated in 3.0.0 has been removed:

```objective-c
- (void)retrieveMessageList;
- (void)performBatchUpdateCommand:(UABatchUpdateCommand)command withMessageIndexSet:(NSIndexSet *)messageIndexSet;
``` 

The following have been deprecated as of 5.0.0:

```objective-c
typedef NS_ENUM(NSInteger, UABatchUpdateCommand);
- (UAInboxMessage*)messageAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfMessage:(UAInboxMessage *)message;
``` 

The `retrieveMessageListWithDelegate` method has been deprecated as of 5.0.0
and replaced with `retrieveMessageListWithSuccessBlock:withFailureBlock:`:

```objective-c
- (UADisposable *)retrieveMessageListWithDelegate:(id<UAInboxMessageListDelegate>)delegate;
``` 

The following methods have been deprecated as of 5.0.0 and replaced with
`markMessagesRead:completionHandler:` or `markMessagesDeleted:completionHandler:`:

```objective-c
- (UADisposable *)performBatchUpdateCommand:(UABatchUpdateCommand)command
                        withMessageIndexSet:(NSIndexSet *)messageIndexSet
                           withSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                           withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock;

- (UADisposable *)performBatchUpdateCommand:(UABatchUpdateCommand)command
                        withMessageIndexSet:(NSIndexSet *)messageIndexSet
                               withDelegate:(id<UAInboxMessageListDelegate>)delegate;
``` 

Added methods in 5.0.0:

```objective-c
- (UADisposable *)markMessagesRead:(NSArray *)messages
                 completionHandler:(UAInboxMessageListCallbackBlock)completionHandler;

- (UADisposable *)markMessagesDeleted:(NSArray *)messages
                    completionHandler:(UAInboxMessageListCallbackBlock)completionHandler;
``` 

## UAInboxMessage Changes

The `markAsRead` method deprecated in 3.0.0 has been removed:

```objective-c
- (BOOL)markAsRead;
``` 

The following methods has been deprecated and replaced with `markMessageReadWithCompletionHandler` in 5.0.0:

```objective-c
- (UADisposable *)markAsReadWithSuccessBlock:(UAInboxMessageCallbackBlock)successBlock
                            withFailureBlock:(UAInboxMessageCallbackBlock)failureBlock;

- (UADisposable *)markAsReadWithDelegate:(id<UAInboxMessageListDelegate>)delegate;
``` 

Method added in 5.0.0:

```objective-c
- (UADisposable *)markMessageReadWithCompletionHandler:(UAInboxMessageCallbackBlock)completionHandler;
``` 

## UAInboxMessageListObserver Changes

The `UAInboxMessageListObserver` functionality deprecated in 3.0.0 has been
replaced with the callback-based methods discussed above, as well as
`NSNotificationCenter` events.

Protocol removed in 5.0.0:

```objective-c
@protocol UAInboxMessageListObserver <NSObject>
``` 

# Urban Airship Library 3.0.0 to 4.0.0

## UAPush Changes

This release added the ability to address opted out devices through channels.

The Channel Identifier is an Urban Airship generated ID that maps to platform push addresses.
The Channel ID is available from UAPush.

Example:

```objective-c
NSString *channelID = [UAPush shared].channelID;
``` 

The channel ID will not be assigned in these conditions:

* When the device does not have an internet connection.

* When the server returns a 501 status code (Channel API not available), we will fall back to registering with the device token.

## UARegistrationObserver

The UARegistrationObserver deprecated in version 3.0.0 has been removed.

## UARegistrationDelegate

The UARegistrationDelegate for registration events has changed to the following:

Called when the device channel and/or device token successfully registers with Urban Airship.
Successful registrations could be disabling push, enabling push, or updating the device registration settings.
A nil channel id indicates the channel creation failed and the old device token registration is being used.
The device token will only be available once the application successfully registers with APNS.

```objective-c
- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(NSString *)deviceToken
``` 

Called when the device channel and/or device token failed to register with Urban Airship.

```objective-c
- (void)registrationFailed
``` 

Implement the `UARegistrationDelegate` protocol and assign to the `[UAPush registrationDelegate]` to receive registration success and failure callbacks.

Example:

```objective-c
[UAPush shared].registrationDelegate = yourUARegistrationDelegate;
``` 

## UAInboxPushHandler Changes

Informing the `UAInboxPushHandler` about notifications is no longer necessary and `handleNotification:` has been removed.  This is now handled in `UAPush handleNotification:applicationState:` and in `UAPush handleNotification:applicationState:fetchCompletionHandler:`.

Methods Removed:

```objective-c
+ (void)handleNotification:(NSDictionary *)userInfo;
``` 

## Custom Inbox UI

In order for custom Inbox UI classes to be compatible with the Actions Framework, a few changes must be made.

The `UIWebViewDelegate` method `webView:shouldStartLoadWithRequest:navigationType` should call through to the method of the same name on the new [UAWebViewTools](https://docs.urbanairship.com/ios-lib/Classes/UAWebViewTools.html) class.

The category extension `UIWebView+UAAdditions` has been moved to the
main library. Any app-level copies of this category should be removed.
The category method `injectViewPortFix` is no longer necessary and
has been removed.

Inbox UI classes can now optionally implement the new [UARichContentWindow](https://docs.urbanairship.com/reference/libraries/ios/latest/Protocols.html#/c:objc(pl)UARichContentWindow) protocol, which provides support for closing windows from JavaScript. Proper behavior of the new `UAirship.close` JavaScript method depends on this protocol, and individual implementations are responsible for determining how best to handle this event.

Additionally, a new JavaScript event has been added allowing rich content pages to detect when the webView has finished loading, named `ualibraryready`. In order to support this event in your custom Inbox UI, make sure to call the following method in your `UIWebViewDelegate`'s `webViewDidFinishLoad:` callback:

```objective-c
[self.webView fireUALibraryReadyEvent];
``` 

If ever in doubt, refer to the updated sample UI classes for an example implementation of these changes.

## UAInboxJavaScriptDelegate

This protocol has been deprecated in favor of [UAJavaScriptDelegate](https://docs.urbanairship.com/reference/libraries/ios/latest/Protocols.html#/c:objc(pl)UAJavaScriptDelegate). New applications bridging JavaScript to native code are encouraged to use the Actions Framework, which depends on an internal implementation of this protocol, or use the new user-asignable [UAirship jsDelegate](https://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAirship.html#/c:objc(cs)UAirship(py)jsDelegate) property on for custom implementations.

`UAInboxJavaScriptDelegate` implementations will continue to work in deprecation. Implementations of the new protocol are required to use the `uairship://` URL scheme as opposed to the deprecated `ua://` scheme.

Support for these deprecated features will be removed after **October 2, 2014**.

# Urban Airship Library 2.1.0 to 3.0.0

This version supports iOS 5, 6, 7 and iOS 7 [Background Push](https://docs.urbanairship.com/platform/ios#background-push).

## Linker Flags

Starting with 3.x, the library makes use of Objective-C categories.  To support categories and prevent "selector not recognized" runtime exceptions, add the linker flag "-ObjC" for "Other Linker Flags" in your projects Build settings.

## ARC Changes

The library now uses Automatic Reference Counting (ARC), so no extra work is
needed if your project is ARC enabled.

For non-ARC projects, compiler flags can be used to set individual source files
to compile as ARC.  Select the target in Xcode, go to the Build Phases screen
and double-click on the source files row in the Compile Sources. Then enter
`-fobjc-arc` in the box and repeat for all your source files.

If you are ready to convert your non-ARC project to ARC, you can use the ARC
Migration Wizard. In Xcode, from the Edit menu, select `Refactor` then
`Convert to Objective-C ARC...`

See the [Transitioning to ARC Release Notes](https://developer.apple.com/library/ios/releasenotes/ObjectiveC/RN-TransitioningToARC/Introduction/Introduction.html)
for more details.

## UAPush Changes

The `UARegistrationObserver` has been replaced with `UARegistrationDelegate`.
The `UARegistrationDelegate` has the same method signatures as
`UARegistrationObserver`, but developers should use the `UARegistrationDelegate`
because `UAObservable` has been deprecated.

The `delegate` property has been replaced with `pushNotificationDelegate`.

Protocol and property deprecated:

```objective-c
@protocol UARegistrationObserver
@property (nonatomic, weak) id<UAPushNotificationDelegate> delegate;
``` 

Properties added:

```objective-c
@property (nonatomic, assign) id<UARegistrationDelegate> registrationDelegate;
@property (nonatomic, weak) id<UAPushNotificationDelegate> pushNotificationDelegate;
``` 

## UAObservable Changes

The UAObservable and all related protocols/methods have been deprecated as of
3.0.0. They have been replaced with three categories: block-based methods,
delegate-based methods, and `NSNotificationCenter` events. This provides the
developer with flexibility on selecting the option best for them. Examples on
implementing these options are provided below.

Interface deprecated:

```objective-c
@interface UAObservable : NSObject;
``` 

## UAInboxMessageList Changes

Methods deprecated:

```objective-c
- (void)retrieveMessageList;
- (void)performBatchUpdateCommand:(UABatchUpdateCommand)command withMessageIndexSet:(NSIndexSet *)messageIndexSet;
``` 

Replaced with block and delegate-based methods:

```objective-c
- (UADisposable *)retrieveMessageListWithSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                                     withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock;

- (UADisposable *)retrieveMessageListWithDelegate:(id<UAInboxMessageListDelegate>)delegate;

- (UADisposable *)performBatchUpdateCommand:(UABatchUpdateCommand)command
                        withMessageIndexSet:(NSIndexSet *)messageIndexSet
                           withSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                           withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock;

- (UADisposable *)performBatchUpdateCommand:(UABatchUpdateCommand)command
                        withMessageIndexSet:(NSIndexSet *)messageIndexSet
                              withDelegate:(id<UAInboxMessageListDelegate>)delegate;
``` 

Implementation example:

```objective-c
// old way
[[UAInbox shared].messageList retrieveMessageList];

// new way with delegates
UADisposable *disposable = [[UAInbox shared].messageList retrieveMessageListWithDelegate:someDelegate];
// OPTIONAL: if you want to cancel *callbacks* before the operation is finished (not the operation in its entirety)
// [disposable dispose];

// new way with blocks
disposable = [[UAInbox shared].messageList retrieveMessageListWithSuccessBlock:^{
    // success!
} withFailureBlock:^{
    // failure :(
}];
// OPTIONAL: you can cancel the success/failure block execution the same way
// [disposable dispose];
``` 

## UAInboxMessage Changes

Method deprecated:

```objective-c
- (BOOL)markAsRead;
``` 

Replaced with block and delegate-based methods:

```objective-c
- (UADisposable *)markAsReadWithSuccessBlock:(UAInboxMessageCallbackBlock)successBlock
                            withFailureBlock:(UAInboxMessageCallbackBlock)failureBlock;

- (UADisposable *)markAsReadWithDelegate:(id<UAInboxMessageListDelegate>)delegate;
``` 

## UAInboxMessageListObserver Changes

The `UAInboxMessageListObserver` functionality has been replaced with the
callback-based methods discussed above, as well as `NSNotificationCenter`
events.

Protocol deprecated:

```objective-c
@protocol UAInboxMessageListObserver <NSObject>
``` 

## New NSNotificationCenter events

In the `UAInboxMessageListObserver` protocol, `messageListWillLoad` would be
followed by `messageListLoaded` or `inboxLoadFailed` depending on the success of
the operation. The same basic pattern also holds for batch updating, where you'd
see a `messageListWillLoad` followed by `batchMarkAsReadFinished`/
`batchMarkAsReadFailed`/etc.

The `NSNotifications` are an attempt to simplify that, since if all you care
about is whether the inbox is currently updating you don't need to implement all
those different success/failure methods in order to continue once the list is
finished updating. For that reason, the `UAInboxMessageListUpdatedNotification`
is *always* called once the operation is finished, regardless of its success/
failure status, and regardless of whether it's a retrieve or batch update
operation.

```objective-c
// NSNotification posted when the message list is about to update.
extern NSString * const UAInboxMessageListWillUpdateNotification;
// NSNotification posted when the message list is finished updating.
extern NSString * const UAInboxMessageListUpdatedNotification;
``` 

Implementation example:

```objective-c
// UAInboxMessageListController.m
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    ...

    // new way with NSNotifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListWillUpdate)
                                                 name:UAInboxMessageListWillUpdateNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListUpdated)
                                                name:UAInboxMessageListUpdatedNotification
                                              object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UAInboxMessageListUpdatedNotification object:nil];
}
``` 

# Urban Airship Library 2.0.0 to 2.1.0

This release is a drop-in replacement for 2.0.x. It supports iOS 7 [Background Push](https://docs.urbanairship.com/platform/ios#background-push)
and also marks the last release for manual reference counting.

# Urban Airship Library 1.4.0 to 2.0.0

## App Delegate Changes

Much of the manual intervention previously required in the app delegate has been made unnecessary, as the library can now handle `UIApplicationDelegate` callbacks on its own, forwarding the calls to your app delegate transparently.

The primary `takeOff` call is still required in the `didFinishLaunchingWithOptions` method.  However, your app delegate no longer needs to implement any of the device token registration callbacks, and the remote notification callback is strictly optional.

Required Methods:

```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
``` 

No Longer Required:

```objective-c
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error;
``` 

Optional Methods:

```objective-c
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;
``` 

It should be noted that the above remote notification callback is fully optional, and it is no
longer necessary to pass the notification into the UA library in order for our analytics to report opens properly.

Instead, developers should implement the `UAPushNotificationDelegate` protocol methods and use these to perform
custom logic such as resetting an application icon badge:

```objective-c
// Called when a notification is received while the application is in the foreground
- (void)receivedForegroundNotification:(NSDictionary *)notification

// Called when the application is started or resumed by a user opening a notification
- (void)launchedFromNotification:(NSDictionary *)notification;
``` 

## UAirship takeOff Changes

`takeOff` no longer requires passing an `NSDictionary`.  Instead create a `UAConfig` model object to
pass into `takeOff`.

Example:

```objective-c
// Create the UAConfig model object.  Loads configuration
// from AirshipConfig.plist
UAConfig *config = [UAConfig defaultConfig];

// Apply any plist overrides to the config object
// e.g., config.developmentAppKey = @"YourKey";

// Call takeOff (which creates the UAirship singleton)
// You may also simply call [UAirship takeOff] without any arguments if you want
// to use the default config loaded from AirshipConfig.plist
[UAirship takeOff:config];
``` 

In addition, it is no longer necessary to call `registerForRemoteNotificationTypes` on `UAPush`.  Instead, set the notification types property as shown below, and the library will register for you automatically:

```objective-c
[UAPush shared].notificationTypes = (UIRemoteNotificationTypeBadge |
                                     UIRemoteNotificationTypeSound |
                                     UIRemoteNotificationTypeAlert);
``` 

For more detailed information on how to customize configuration, see [iOS Advanced Features](https://docs.urbanairship.com/platform/ios#platform-ios-advanced).

## UAInboxUI Protocol Changes

Protocol methods removed:

```objective-c
+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID;
``` 

Protocol methods added:

```objective-c
+ (void)displayInboxInViewController:(UIViewController *)parentViewController animated:(BOOL)animated;
+ (void)displayMessageWithID:(NSString *)messageID inViewController:(UIViewController *)parentViewController;
``` 

These core UI protocol methods have been slightly renamed in order to better represent their functionality.

## UAInbox Changes

Methods removed:

```objective-c
+ (void)displayInbox:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)displayMessage:(UIViewController *)viewController message:(NSString*)messageID;
``` 

Methods added:

```objective-c
+ (void)displayInboxInViewController:(UIViewController *)parentViewController animated:(BOOL)animated;
+ (void)displayMessageWithID:(NSString *)messageID inViewController:(UIViewController *)parentViewController;
``` 

Since these methods are simply convenience wrappers around the `UAInboxUI` protocol methods mentioned above, they have changed as well to match the new protocol method definitions.

## UAInboxPushHandlerDelegate Protocol Changes

Protocol methods removed:

```objective-c
- (void)newMessageArrived:(NSDictionary *)message;
``` 

Protocol methods added:

```objective-c
- (void)richPushNotificationArrived:(NSDictionary *)notification;
- (void)applicationLaunchedWithRichPushNotification:(NSDictionary *)notification;
- (void)richPushMessageAvailable:(UAInboxMessage *)richPushMessage;
- (void)launchRichPushMessageAvailable:(UAInboxMessage *)richPushMessage;
``` 

The protocol method `newMessageArrived` has been replaced with the more aptly named `richPushNotificationArrived`,
which more closely follows the pattern used in the non-rich push sections of the library, and more aptly represents the
event taking place.  This method is called when a new rich push notification is received, but before the inbox contents
have been updated with the associated message content. We have also added a companion method, `applicationLaunchedWithRichPushNotification`, which is called when the user opens the app by tapping a rich push notification in the iOS message center.

In prior library versions, bridging push events such as these with the display of rich message contents
was always somewhat cumbersome.  We've simplified this flow with two new methods: `richPushMessageAvailable`
and `launchRichPushMessageAvailable`.  As of version 2.0.0, the library will automatically update the inbox contents
following the delivery of a rich push notification, and when the associated message is available for viewing, one of
these two methods will be called.  Just as above, these events are separated between in-app and launch notification
scenarios, allowing developer to wire up custom logic for these cases if they so choose.

## UAInboxAlertHandler Changes

Methods removed:

```objective-c
- (void)showNewMessageAlert:(NSString *)message;
``` 

Methods added:

```objective-c
- (void)showNewMessageAlert:(NSString *)message withViewBlock:(UAInboxAlertHandlerViewBlock)viewBlock;
``` 

In the `UAInboxAlertHandler` class, the public method `showNewMessageAler` has been replaced with `showNewMessageAlert:withViewBlock`, which allows the developer to pass in a block to be executed if the user taps *View* in the displayed alert dialog.  Historically this class has been used in our reference implementations of the `UAInboxPushHandlerDelegate` protocol in the `UAInboxUI` and `UAInboxNavUI` classes, to facilitate viewing rich messages as they come in while the app is running.  With the changes to the protocol outlined above, it is now the responsibility of the delegate to defer message display to the appropirate event, namely when the message is available for display.

An example taken from the reference `UAInboxUI` implementation is shown below:

```objective-c
- (void)richPushMessageAvailable:(UAInboxMessage *)richPushMessage {
    NSString *alertText = richPushMessage.title;
    [self.alertHandler showNewMessageAlert:alertText withViewBlock:^{
        [[UAInbox shared].uiClass displayMessageWithID:richPushMessage.messageID inViewController:nil];
    }];
}
``` 

## UAPush Changes

Deprecated Methods removed:

```objective-c
- (void)enableAutobadge:(BOOL)enabled
- (void)updateTags:(NSMutableArray *)values
- (void)updateAlias:(NSString *)value
- (void)disableQuietTime
- (void)tz
- (void)setTz
``` 

Device registration methods and property functionality was removed. These details are now handled internally by the SDK.

```objective-c
- (void)registerDeviceTokenWithExtraInfo:(NSDictionary *)info;
- (void)registerDeviceToken:(NSData *)token withAlias:(NSString *)alias;
- (void)registerDeviceToken:(NSData *)token withExtraInfo:(NSDictionary *)info;
- (void)unRegisterDeviceToken;

@property (nonatomic, assign) BOOL retryOnConnectionError;
``` 

Demonstration methods have been removed, though they can still be found in `UAPushUI`:

```objective-c
+ (void)openTokenSettings:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)closeTokenSettingsAnimated:(BOOL)animated;
``` 

Properties renamed:

```objective-c
@property (nonatomic, assign) BOOL deviceTagsEnabled;  // Use to be canEditTagsFromDevice
``` 

The land method is now internal only. It will be called automatically with the new auto app delegate.

```objective-c
+ (void)land;
``` 

## UAPushNotificationDelegate Protocol Changes

Protocol methods removed:

```objective-c
// Called when a notification is received while the application is in the foreground
- (void)receivedForegroundNotification:(NSDictionary *)notification;

// Called when the application is started or resumed by a user opening a notification
- (void)launchedFromNotification:(NSDictionary *)notification;
``` 

Protocol methods added:

```objective-c
- (void)receivedForegroundNotification:(NSDictionary *)notification;
- (void)launchedFromNotification:(NSDictionary *)notification;
``` 

## UAPushUIProtocol Protocol Changes

Demonstration methods have been removed, they can still be found in `UAPushUI`:

```objective-c
+ (void)openTokenSettings:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)closeTokenSettingsAnimated:(BOOL)animated;
``` 

## UARegistrationObserver Protocol Changes

Protocol methods renamed:

```objective-c
- (void)unregisterDeviceTokenSucceeded; // Renamed from unRegisterDeviceTokenSucceeded
- (void)unregisterDeviceTokenFailed:(UAHTTPRequest *)request; // Renamed from unRegisterDeviceTokenFailed
``` 
