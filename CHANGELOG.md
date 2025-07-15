
# iOS 18.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)

[All Releases](https://github.com/urbanairship/ios-library/releases)

## Version 18.14.4 July 15, 2025
Patch release backported to ensure in-app views are still in the window hierarchy before updating constraints.

### Changes
- Fixed crash caused by constraints updating when in-app view isn't in the view hierarchy.

## Version 18.14.3 January 31, 2025
Patch release backported to fix landing page dismiss button default color on iOS and crash caused by banner size changes during dismissal.

### Changes
- Updated landing page dismiss button default color on iOS to black.
- Fixed crash caused by banner size changes during dismissal.

## Version 18.14.2 January 9, 2025
Patch release to fix extra spacing in a Banner In-App Automations if its missing the heading or body.

### Changes
- Fixed Banner In-App Automation extra spacing.

## Version 18.14.1 December 20, 2024
Patch release to fix Banner In-App Automations if the image is taller than the text.

### Changes
- Fixed Banner In-App Automation sizing issue.

## Version 18.14.0 December 19, 2024
Minor release that fixes issues with Banner In-App Automations, reduces power usage with In-App Automations & Scenes, and updates how Feature Flags are resolved. 

### Changes
- Added `resultCache` to `FeatureFlagManager`. This cache is managed by the app and can be optionally used when resolving a flag as a fallback if the flag fails to resolve or if
the flag rule set does not exist.
- FeatureFlag resolution will now resolve a rule set even if the listing is out of date.
- Fixed issue with In-App Automation banners constraints, causing the banner to sometimes steal focus from the underlying app screen or not fully display.
- Fixed issue with Surveys that require multi choice or single choice questions not blocking submission.
- Reduced the CPU overhead with In-App Automations & Scene execution to reduce overall power usage.


## Version 18.13.0 December 5, 2024
Minor release that improves a11y support, updated Preference Center UI, and fixes several minor and improvements in Scenes and in-app message banners.

### Changes
- Added support for email collection in Scenes
- Updated Preference Center UI to use standard padding, titles, and colors to improve the look and feel across different platforms.
- Added support to mark a label as a heading in Scenes.
- Added support for auto-height modals in Scenes.
- Fixed banner duration not dismissing the banner.
- Fixed dismissal issues for banners with a height less than 100pts.
- Fixed padding issue in bottom-placed in-app banners.

## Version 18.12.2 November 26, 2024
Patch release that resolves a minor memory-related bug and adds more useful logging around Feature Flag evaluation.

### Changes
- Fixed minor memory-related bug that could result in a rare crash.
- Improved logging around Feature Flag evaluation.

## Version 18.12.1 November 6, 2024
Patch release that resolves an issue with Firebase integrations in React Native and Flutter and an issue with opt-in checks when `requestAuthorizationToUseNotifications` is set to false.

### Changes
- Fixed issues caused by swizzling conflicts with some Firebase framework integrations.
- Fixed opt-in check permissions querying when `requestAuthorizationToUseNotifications` is set to false.

## Version 18.12.0 November 1, 2024
Minor release with several enhancements to Scenes.

### Changes
- Added box shadow support for modal Scenes.
- Added a new implementation of the Scene pager to lazily load pages on iOS 17+, reducing the overall memory while a Scene is displaying.
- Added new Scene layout to allow adding actions to anything within a Scene.
- Added additional logging to deep link handling to make it obvious how the deep link is being processed
- Updated border handling on Scenes. Borders are no longer overlaid to avoid issues with borders that are not fully opaque and button borders being overdrawn when tapped.
- Improved accessibility of scene story indicator. Indicator has been updated to make it obvious which page is active by reducing the height of the inactive pages. Previously this was conveyed only through color.
- Fixed center_crop scaling in a Scene when a dimension is `auto` but the image is unable to fully fit in the container.
- Fixed IAA banners drag to dismiss gesture when the gestures starts within a button.

## Version 18.11.1 October 15, 2024
Patch release to avoid implicit unwrap when UINavigationBar appearance tintColor is unset. Applications that use the PreferenceCenter should update.

### Changes
- Removes implicit unwrap of the UINavigationBar appearance tintColor.

## Version 18.11.0 October 11, 2024
Minor release with Message Center and Preference center theming bug fixes and improvements, and a bug fix for IAA videos. Applications that send IAA videos or theme the Message Center or Preference Center and should update.

### Changes
- Improved Message Center theming with a focus on improving nagivation components.
- Improved Preference Center theming with a focus on improving nagivation components.
- Fixed an issue that prevented IAA videos from properly displaying.

## Version 18.10.0 October 3, 2024
Minor release with accessibility updates, Message Center theming improvements and several bug fixes.

### Changes
- Fixed Message Center background color and back button theming.
- Fixed tap events in Scenes being registered by their containers in some instances.
- Improved accessibility support in Scenes, Message Center and Preference Center with paging actions, localized content descriptions and traits.
- Added ability to theme Message Center with a custom style.
- Updated webview backgrounds to be clear when displaying media.

## Version 18.9.2 September 23, 2024
Patch release to fix an issue with high energy usage for In-App Automations, Scenes, and Surveys that was introduced in 18.0.0. This issue is
not very common but it can occur if the device is unable to connect to our backend to fetch an update to the In-App rules on the device after an SDK
update or locale change. Application that are receiving high energy usage reports should update.

### Changes
- Fixed high energy usage for In-App Automations, Scenes, and Surveys if remote-data fails to refresh.
- Fixed requesting additional notification options if they change after the first prompt.

## Version 18.9.1 September 13, 2024
Patch release to fix Scene button not able to be tapped in some cases.

#### Changes
- Fixed Scene buttons not able to be tapped if the last page of the scene contains a wide image background.

## Version 18.9.0 September 10, 2024
Minor release that introduces `fallback` parameter when requesting permission updates and the permission is denied. This release also contains
a fix for a regression in 18.8.0 where Channel Registration would continuously update for channels that have upgraded from an earlier
SDK versions. Applications using 18.8.0 should update.

#### Changes
- Added new method `Airship.permissionsManager.requestPermission(_:enableAirshipUsageOnGrant:fallback:)` and `Airship.push.enableUserPushNotifications(fallback:)` that allows you to specify a
fallback behavior if the permission is already denied.
- Fixed high CPU issues with embedded messages that define a percent based size.
- Fixed Channel Registration bug that was introduced in 18.8.


## Version 18.8.0 September 6, 2024
Minor release with several enhancements to In-App Automation, Scenes, and Surveys.

**This version has a regression and should be avoided. Please use 18.9.0 or newer instead**

### Changes
- Added support to disable plain markdown (text markup) support in a Scene.
- Added support to theme markdown links in a Scene.
- Added execution window support to In-App Automation, Scenes, and Surveys.
- Added `displayNotificationStatus` status to the `AirshipNotificationStatus` object to get the user notification permission status.
- Added `Airship.permissionManager.statusUpdates(for:)` that returns an async stream of permission status updates.
- Added `MessageCenter.shared.inbox.unreadCountUpdates` that returns an async stream of unread count updates.
- Added `MessageCenter.shared.inbox.messageUpdates` that returns an async stream of message updates.
- Updated handling of priority for In-App Automation, Scenes, and Surveys. Priority is now taken into consideration at each step of displaying a message instead of just sorting messages that are
triggered at the same time.
- Updated handling of long delays for In-App Automation, Scenes, and Surveys. Delays will now be preprocessed up to 30 seconds before it ends before the message is prepared.
- Fixed Message Center theme loader when trying to theme the OOTB Message Center window.

## Version 18.7.2 August 9, 2024
Patch release that fixes in-app experience displays when resuming from a paused state. Apps that use in-app experiences are encouraged to update.

### Changes
- Fixed Automation Engine updates when pause state changes.

## Version 18.7.1 August 1, 2024
Patch release that prevents In-App Automation, Scenes, and Surveys from being able to trigger off custom events or screen views
when analytics is disabled. The actual event was not being tracked by Airship in these cases, just processed locally.

### Changes
- Prevent screen view and custom events from being processed by automations when analytics is disabled.

## Version 18.7.0 July 30, 2024
Minor release that fixes some layout issues with images and videos in a Scene, accessibility improvements, and fixes a potential crash with JSON encoding/decoding due 
to using a JSONEncoder/JSONDecoder across threads.

### Changes
- Fixed video & image scaling/cropping in scenes.
- Removed reusing JSONEncoder/JSONDecoder across tasks.
- Removed @MainActor requirement from AirshipPush.authorizedNotificationSettings.
- Announce screen changes when banners In-App messages are displayed.
- `MessageCenterController` is now optional when creating a `MessageCenterView`.

## Version 18.6.0 July 12, 2024
Minor release with some improvements to preference center, a fix for in-app message veritcal sizing, accessibility improvements and plain markdown support in scenes.

### Changes
- Added warning message to preference center email entry field.
- Updated preference center country_code.
- Fixed bug preventing preference center channel management from fully opting-out registered channels.
- Fixed padding bug preventing modal in-app messages from properly sizing to their content.
- Added accessibility improvements.
- Added markdown support to scenes.

## Version 18.5.0 July 1, 2024
Minor release that includes cert pinning and various fixes and improvements for Preference Center, In-app Messages and Embedded Content.

### Changes
- Added ability to inject a custom certificate verification closure that applies to all API calls.
- Added width and height parameters to in-app dismiss button theming.
- Fixed bug that caused HTML in-app message backgrounds to default to clear instead of system background.
- Fixed extra payload parsing in in-app messages.
- Set default banner placement to bottom.
- Increased impression interval for embedded in-app views.
- Improved in-app banner view accessibility.
- Preference center contact channel listing is now refreshed on foreground and from background pushes.

## Version 18.4.1 June 21, 2024
Patch release to fix a regression with IAX ignoring screen, version, and custom event triggers. Apps using those triggers that are on 18.4.0 should update.

### Changes
- Fixed trigger regression for IAX introduced in 18.4.0.

## Version 18.4.0, June 14, 2024
Minor release that adds contact management support to the preference center, support for anonymous channels, per-message in-app message theming, message center customization and logging improvements. Apps that use the message center or stories should update to this version.

### Changes
- Added support for anonymous channels.
- Added contact management support in preference centers.
- Added improved theme support and per message theming for in-app messages.
- Added public logging functions.
- Fixed bug in stories page indicator.
- Fixed message center list view background theming.

## Version 18.3.1, May 27, 2024
Patch release with bug fix for message center customization. Apps that use the message center should update to this version.

### Changes
- Fixed background color application in message center.

## Version 18.3.0, May 20, 2024
Minor release with updates to message center customization, a bug fix for story pager transition animation and a bug fix for in-app banner button rendering.

### Changes
- Fixed in-app message banner button rendering.
- Fixed story pager transition animation.
- Added message center list and list container background color customization via new plist keys `messageListBackgroundColor`, `messageListBackgroundColorDark`, `messageListContainerBackgroundColor` and `messageListContainerBackgroundColorDark`

## Version 18.2.2, May 15, 2024
Patch release includes a fix for submission issues when building with XCFrameworks, a bug fix for emitting pager events from in-app pager views, and a bug fix for the in-app banner's default title and body alignment to match the dashboard preview. Apps using XCFrameworks should update.

### Changes
- Fixed pager event emission from in-app pager views.
- Fixed submission issue when building with XCFrameworks.
- Fixed in-app banner title and body default alignment.

## Version 18.2.1, May 14, 2024
Patch release that makes IAA name property is optional and defaults to an empty string.

### Changes
- Fixed InAppMessage parsing to handle the optional name property.
- Ignore invalid schedules on parsing.

## Version 18.2.0, May 7, 2024
Minor release with updates for in-app message customization, video playback improvements in scenes, web view inspection configuration and several bug fixes. Apps that require obj-c support or are migrating from an older version of the SDK to 18.x should update to this version.

### Changes
- Added in-app message tap opacity and shadow customization via new plist keys `tapOpacity` and `shadowTheme`.
- Added isWebViewInspectionEnabled key to AirshipConfig that allows enabling or disabling web view inspection on Airship created web views. Applied only to iOS 16.4+.
- Added improvements for video playback in scenes.
- Fixed CoreData migration errors from SDK 16 and SDK 17 to SDK 18.
- Fixed in-app message banner display issues within navigation controllers.
- Exposed push singelton to Objective-C
- Exposed UAnotificationServiceExtension to Objective-C.

## Version 18.1.2, April 29, 2024
Patch release with a bug fix for data migration. Apps migrating from an older version of the SDK to 18.x using cocoapods should update to this version.

### Changes
- Exposes mapping classes UARemoteDataMapping and UAInboxDataMapping to obj-c and removes module-specific prefixes from mapping files.

## Version 18.1.1, April 23, 2024
Patch release with a bug fix for contact operations.

### Changes
- Fixed a typo in the dutch translation of the notification action button "Vertel Mij Meer".
- Fixed obj-c bindings not being public.

## Version 18.1.0 April 16, 2024

Minor release with several minor API additions.

### Changes
- `MessageCenterInboxProtocol` changes:
  - Added new method `refreshMessages(timeout:)` that will throw if a timeout is reached.
  - Updated the method `refreshMessages()` to properly cancel if the task is cancelled.
  - Refreshing messages will no longer block on network connection availability.
- Added property `identifierUpdates` on `AirshipChannelProtocol` that provides a stream of updates whenever the channel ID changes.
- Added new `AirshipConfig` properties:
  - `resetEnabledFeatures` to reset the `PrivacyManager` enabled features to those specified in config on init.
  - `restoreMessageCenterOnReinstall` to control Message Center recovery on reinstall.
- Added `quietTime` property on `AirshipPushProtocol` to be able to get/set quiet time start and end time.
- Custom event properties will now accept any `Encodable` values and be automatically encoded to JSON.
- Added support for attributing a custom event to an in-app message if the event was generated from the message.
- Updated the LICENSE file to use the standard Apache 2.0 text to be properly detected by Github. The license did not change, only the text describing the license.
- Fixed `Package.swift` to properly support `VisionOS` platform.
- Fixed in-app messages that were interrupted during display that define a display interval not able to be triggered for display again until the next app init.

## Version 16.12.7, April 11, 2024
Patch release that adds a privacy manifest

### Changes
- Adds privacy manifest.

## Version 17.10.0, April 4, 2024
Minor release with a new config option `resetEnabledFeatures` to reset the PrivacyManager enabled features to those specified in the Airship config on each launch and a bug fix for the delete button theming in the Message Center and back button theming in message views.

### Changes
- Added `resetEnabledFeatures` config option
- Fixes color theme assignment for the delete button in Message Center and back button in message views.


## Version 18.0.1 March 22, 2024

Patch release that fixes a few regressions with 18.0.0.

### Changes
- Fixed issue with frequency checks being checked before the message is ready to display
- Fixed an issue with InApp potentially being blocked when upgrading from the prerelease version of 18.0.0 to the final version of 18.0.0


## Version 18.0.0 March 21, 2024

Major SDK release with several breaking changes. see the [Migration Guide](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration/migration-guide-17-18.md) for more info.

### Changes
- Xcode 15.2+ is now required
- Added support for starting Live Activities from a push
- Notification Service extension is now rewritten in Swift
- New Swift Automation module
  - Objective-c support has been removed
  - Breaking API changes for any apps using custom display adapters
  - Added concurrent automation processing to reduce latency if more than one automation is triggered at the same time
- Badge modification methods are now async and use the updated UserNotification methods
- Consolidated NSNotificationNames and keys to AirshipNotifications class
- Replaced access to AirshipPush, AirshipContact, AirshipChannel, AirshipAnalytics with protocols
- Updated Airship accessors to all be class vars instead of a mix of class and instance vars
- Preliminary VisionOS support when using XCFrameworks or SPM
- Added window animations for Scene & Survey transitions
- Fixed Core Data warnings with Xcode 15
- Fixed various sendable warnings when using targeted concurrency checking
