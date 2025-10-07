
# iOS 19.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)
[All Releases](https://github.com/urbanairship/ios-library/releases)

Version 19.11.1 – October 7, 2025
Patch release addressing the longstanding Swift concurrency crash (GH-434) and improving the internal rate-limiting system for better stability and efficiency.

Changes
- Refactored WorkRateLimiter to improve efficiency and reliability, reduce memory overhead, and eliminate unnecessary temporary allocations.
- Added stronger safeguards to WorkRateLimiter prevent rare edge-case crashes in rate-limiting logic.

## Version 19.11.0 - September 30, 2025

This is an important update for apps using manual push notification integration (automaticSetup = false). We are addressing a lifecycle issue caused by Apple's async notification delegate being called on a background thread, unlike the main-thread-guaranteed completionHandler version. To align with the correct lifecycle, we are deprecating our async handler and introducing a new completionHandler method. Using the async version can cause
direct open counts to be lower than expected.

### Changes
- Added a new synchronous `AppIntegration.userNotificationCenter(_:didReceive:withCompletionHandler:)` method. Apps must use this and the corresponding synchronous delegate method to ensure notification responses are handled before the app becomes active.
- The async `AppIntegration.userNotificationCenter(_:didReceive:)` method is now deprecated.
- Landing pages no longer display for push notifications received when the app is in the foreground.



## Version 19.10.0 - September 22, 2025
Minor release that adds a new flag to work around the critical crash (GH-434) affecting Swift 5 apps on Xcode 16.1+. The problematic feature is now disabled by default.

### Changes
- Added `isDynamicBackgroundWaitTimeEnabled` flag. This defaults to `false` to avoid the crash. It is strongly recommended to keep this `false` for Swift 5 apps. Swift 6 apps can safely set this to `true` to restore previous behaviors.

## Version 19.9.2 - September 15, 2025
Patch release that resolves a crash eminating from the Thomas video player, fixes a bug that causes Scenes to sometimes display after being stopped, and fixes some UI bugs exposed by iOS 26.

### Changes
- Fixed refreshing out of date In-App Automations and Scenes before displaying.  
- Fixed KVO in ThomasVideoPlayer to use modern patterns and properly release observers.
- Fixed Message Center title bar theming in iOS 26.
- Improved tab bar UI in iOS 26.


## Version 19.9.1 - September 10, 2025
Patch release that fixes backwards Swift 5 compatibility. Users that plan to use the 19.9.1-swift5 branch are encouraged to update.

### Changes
- Fixed default parameter initialization by moving @MainActor object creation from parameter defaults to method bodies in ThomasEnvironment, ThomasState, and ThomasFormField.

## Version 19.9.0 - September 4, 2025
Minor release that adds a new flag to HTML In-App message content to force full screen on all devices.

### Changes
- Added `forceFullScreen` to HTML In-App message content

### Version 19.8.3 - August 25, 2025

A patch release that includes a targeted fix for the ongoing Swift interoperability crashes outlined in GH-434.

### Changes
- Updated the concurrency pattern in the background task scheduler, replacing a `for-await` loop with a `TaskGroup`. This change targets a suspected instability in Swift's concurrency runtime and is expected to mitigate the crashes seen in mixed Swift 5/6 environments.
- Fixed a Scene issue where labels marked as H3 were being treated as H1.
- Improved accessibility of embedded Scenes by announcing screen changes when an embedded view is displayed.

## Version 19.8.2 - August 19, 2025
A patch release with bug fixes for video in scenes and Swift interoperability crashes. Users that have upgraded to SDK 19.6.0+ and display Youtube or Vimeo videos in Scenes or In-app Messages or are experiencing crashes like those outlined in GH-434 are encouraged to update. 

### Changes
- Fixed bug preventing proper rendering of youtube and vimeo videos in Scenes and In-app Messages.
- Fixed Swift 5-6 interop issues causing crashes in Workers.calculateBackgroundWaitTime(maxTime:) outlined in github issue 434.

## Version 19.8.1 - August 6, 2025
A patch release with improved Xcode 26 support, a fix for custom font scaling in scenes, and internal improvements to image loading.

### Changes
- Fixed issues affecting custom font scaling.
- Improved image loading support.
- Fixed a compilation error caused by SwiftUICore import exposed by Xcode 26 beta 4.

## Version 19.8.0 - July 24, 2025
A minor release with improvements to Scenes and a new `dismiss` command for the JS interface.

### Changes
- Added support in Scenes for linking form inputs to a label for better accessibility.
- Added container item alignment to Scenes to change the natural alignment within a container.
- Added a new `dismiss` command to the JavaScript interface for parity with Android. The new `UAirship.dismiss()` method behaves the same as `UAirship.cancel()`.

## Version 19.7.0 - July 18, 2025
A minor release that simplifies takeOff by deprecating methods with launchOptions, adds flexibility for initialization, and includes several bug fixes.

### Changes
- Deprecated `Airship.takeOff` methods that include launchOptions. The takeOff method still needs to be called before `application(_:didFinishLaunchingWithOptions:)` finishes to ensure proper notification delegate is set up.
- Updated `Airship.takeOff` to allow it to be called from `MainApp.init` before the application delegate is set, even with automatic setup enabled.
- Fixed a stack overflow exception when using Scenes in the iOS 26 beta.
- Added a potential workaround for reported crashes within `AirshipWorkManager` and `AirshipChannel`.
- Fixed a race condition in Scene asset file operations and improved file management.

## Version 19.6.1 - June 24, 2025
Patch release with bug fixes for memory management, survey interactions, and accessibility improvements.

### Changes
- Fixed a memory issue in `AirshipWorkManager` where temporary arrays were being created unnecessarily when calculating background wait times.
- Fixed an issue where NPS survey score selection required double-tapping by properly restoring both the score value and index when loading from form state.
- Fixed a potential crash when updating constraints for banner views that have been removed from the view hierarchy.
- Improved VoiceOver accessibility by ensuring toggles, checkboxes, and radio inputs remain accessible even without explicit accessibility descriptions.
- Added accessibility header traits to section titles in Message Center, Preference Center, and other UI components for better VoiceOver navigation.

## Version 19.6.0 - June 17, 2025
A minor update with enhancements to Scenes and Message Center functionality and a bug fix for Automation. This version is required for Scene branching and phone number collection.

### Changes
Automation:
- Fixed version trigger predicate matching to properly evaluate app version conditions.

Message Center:
- Added support to automatically pick up UIKit navigation controller styling.

Scenes:
- Fixed layout issues with modal frames, specifically related to margins and borders.
- Fixed several issues related to Scene branching.
- Added support for custom corner radii on borders.
- Added support for more flexible survey toggles.

## Version 19.5.0 - May 23, 2025
Minor release focused on performance improvements for Scenes.

### Changes
- Improved load times for Scenes by prefetching assets concurrently.

## Version 19.4.0 - May 15, 2025
Minor release that adds support for using Feature Flags as an audience condition for other Feature Flags and Vimeo videos in Scenes.

### Changes
- Added support for using Feature Flags as an audience condition for other Feature Flags.
- Added support for Vimeo videos in Scenes.

## Version 19.3.2 - May 8, 2025
Patch release that fixes Message Center listing not refreshing on push received. This issue was introduced in 19.0.0. Apps using Message Center should update.

### Changes
- Fixed Message Center behavior on push received.

## Version 19.3.1 - Apr 28, 2025
Patch release that fixes an issue in a branching scene where a button required two presses to navigate to the next page instead of one. Apps planning on using the upcoming branching feature should update.

### Changes
- Fixed Scene button navigation with branching.

## Version 19.3.0 - Apr 24, 2025
Minor release adding branching and SMS support for Scenes.

### Changes
- Added support for branching in Scenes.
- Added support for phone number collection and registration in Scenes.
- Added `Airship.inAppAutomation.statusUpdates` to track rule update statuses for In-App Automation, Scenes, and Surveys.
- Added `Airship.featureFlagManager.statusUpdates` to monitor rule update statuses.
- Added support for setting JSON attributes for Channels and Contacts.
- Added missing bindings for Obj-C.
- Improved accessibility for Banner In-App messages and automations.
- Added `TagActionMutation` stream to emit tag updates from `AddTagsAction` and `RemoveTagsAction`.

## Version 19.2.1 - Apr 17, 2025
Resolved a regression introduced in 19.2.0 where channel audience updates and In-App experiences were unintentionally blocked when the Contact privacy manager flag was disabled. 

### Changes
- Fixed Channel operations and IAX being blocked when Contacts are disabled.

## Version 19.2.0 - Apr 3, 2025
Minor release with Custom Views functionality allowing native SwiftUI views to be displayed in Scenes.

### Changes
- Added Custom Views functionality allowing native SwiftUI views to be displayed in Scenes.

## Version 19.1.2 - March 31, 2025
Patch release with bug fix for swipe gestures in Scenes.

### Changes
- Fixed regression that caused horizontal swipe gestures to be disabled on some devices.

## Version 19.1.1 - March 25, 2025
Patch release with bug fixes and minor improvements.

### Changes
- Fixed a bug that allowed channel registration updates to proceed in certain cases when all features were disabled via the Privacy Manager.
- Fixed a potential bug involving unecessary comparison checks in the layout system.

## Version 19.1.0 - February 20, 2025
Minor release that adds support for email registration in Scenes, fixes bugs, and improves Airship configuration, Scene keyboard avoidance, and logging.

### Changes
- Updated the keyboard avoidance for Scenes to use standard window insets
- Added `resolveInProduction()` method on `AirshipConfig` to expose how Airship resolves the `inProduction` flag during takeOff
- Added support for email registration in Scenes
- Fixed regression with log level check that was introduced in 19.0.0
- Fixed voice over with NPS score for Surveys
- Added logger to `UANotificationServiceExtension`. The logger can be configured by overriding the `airshipConfig` property.
- Fixed Carthage build failures caused by UIKit Sample project

## Version 19.0.3 - February 4, 2025
Patch release to fix a crash caused by combine subjects being updated from multiple queues.

### Changes
- Fixed a crash caused by combine subjects being updated from multiple queues

## Version 19.0.2 - January 31, 2025
Patch release to fix a crash caused by banner size changes during dismissal.

### Changes
- Fixed crash caused by banner size changes during dismissal.

## Version 19.0.1 - January 29, 2025
Patch release that fixes a crash when the device toggles airplane mode. Apps using 19.0.0 should update.

### Changes
- Fixed crash in `WorkConditionsMonitor` when the device toggles airplane mode.
- Added `@MainActor` to `RegistrationDelegate` protocol methods.
- Updated default dismiss button color from white to black for landing pages to match Android.
- Removed top padding on modal and full screen IAAs when using header_media_body and header_body_media without anything above the media.

## Version 19.0.0 - January 16, 2025
Major SDK release with several breaking changes. see the [Migration Guide](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration/migration-guide-18-19.md) for more info.

### Changes
- Xcode 16.2+ is now required.
- Updated min versions to iOS 15+ & tvOS 18+.
- Migrated all modules to Swift 6.
- Objective-C support has been moved into AirshipObjectiveC framework freeing the SDK to expose Swift only APIs.
- Updated several APIs to use structs instead of classes.
- AppIntegration and PushNotificationDelegate expose async methods instead of completion handlers.
- Airship.takeOff can now throw instead of silently failing for better error handling.
- New CustomEvent template APIs.
- Remove unused NotificationContent extension.
- Fixed Scene animation when the device screen orientation changes with auto-height modals.
- Added support for wrapping score views in Scenes.
- Added support for Preference Center and Feature Flags to tvOS.
- Added support for Feature Flag experimentation.

