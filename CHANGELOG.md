
# iOS 19.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)
[All Releases](https://github.com/urbanairship/ios-library/releases)

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

