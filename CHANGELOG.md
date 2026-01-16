
# iOS 20.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)
[All Releases](https://github.com/urbanairship/ios-library/releases)

## Version 20.1.1 - January 16, 2026
Patch release that improves VoiceOver focus control and sizing for the progress bar indicator in Story views.

### Changes
- Added support for sizing inactive segments in Story view progress indicators.
- Improved VoiceOver focus handling for Message Center Web content.

## Version 20.1.0 - January 9, 2026
Minor release that includes several fixes and improvements for Scenes, In-App Automations, and Message Center.

### Changes
- Added support for Story pause/resume and back/next controls.
- Added Scenes content support in Message Center.
- Added support for additional text styles in Scenes.
- In-App Automations and Scenes that were not available during app launch can now be triggered by events that happened in the previous 30 seconds.
- Fixed pinned container background image scaling when the keyboard is visible in Scenes.
- Fixed banner presentation and layout in Scenes.
- Fixed progress icon rendering in Scenes.
- Fixed container layout alignment in Scenes.

## Version 20.0.3 - December 17, 2025
Patch release that fixes keyboard safe area with Scenes.

### Changes
- Fixed safe area handling during keyboard presentation in Scenes.

## Version 20.0.2 - November 24, 2025
Patch release that fixes an issue with delayed video playback in Scenes when initially loading or paging and addresses a direct open attribution race condition which could cause direct open events to be missed in some edge cases.

### Changes
- Fixed an issue where the video ready callback was not assigned before observers were set up, causing the pager to miss the ready signal and advance before they loaded completely.
- Fixed a potential race condition that could result in missed direct open attributions by ensuring notification response handling completes synchronously before the app becomes active.

## Version 20.0.1 - November 14, 2025
Patch release that fixes several minor bugs and adds accessibility improvements.

### Changes
- Fixed looping behavior in video views within Scenes.
- Fixed Message Center icon display when icons are enabled.
- Fixed pager indicator accessibility to prevent duplicate VoiceOver announcements.
- Added dismiss action to banner in-app messages for improved VoiceOver accessibility.
- Fixed YouTube video embedding to comply with YouTube API Client identification requirements.

## Version 20.0.0 - October 9, 2025
Major SDK release with several breaking changes. See the [Migration Guide](https://github.com/urbanairship/ios-library/blob/main/Documentation/Migration/migration-guide-19-20.md) for more info.

### Changes
- Xcode 26+ is now required.
- Updated minimum deployment target to iOS 16+.
- Refactored Message Center and Preference Center UI to provide clearer separation between navigation and content views. See the migration guide for API changes.
- Introduced modern, block-based and async APIs as alternatives to common delegate protocols (`PushNotificationDelegate`, `DeepLinkDelegate`, etc.). The delegate pattern is still supported but will be deprecated in a future release.
- Refactored core Airship components to use protocols instead of concrete classes, improving testability and modularity. See the migration guide for protocol renames and class-to-protocol conversions.
- Added support for split view in the Message Center, improving the layout on larger devices.
- Updated the Preference Center with a refreshed design and fixed UI issues on tvOS and visionOS.
- Fixed Package.swift to remove macOS as a supported platform.
- CustomViews within a Scene can now programmatically control their parent Scene, enabling more dynamic and interactive custom content.
- Accessibility updates for Scenes.
- New AirshipDebug package that exposes insights and debugging capabilities into the Airship SDK for development builds, providing enhanced visibility into SDK behavior and performance.
- Removed automatic collection of `connection_type` and `carrier` device properties
