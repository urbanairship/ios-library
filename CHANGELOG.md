
# iOS 20.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)
[All Releases](https://github.com/urbanairship/ios-library/releases)


## Version 20.0.0 - October 2, 2025
Major SDK release with several breaking changes. See the [Migration Guide](Documentation/Migration/migration-guide-19-20.md) for more info.

### Changes
- Xcode 26+ is now required.
- Updated minimum deployment target to iOS 16+.
- Refactored Message Center and Preference Center UI to provide a clearer separation between navigation and content views. See migration guide for API changes.
- Introduced modern, block-based and async APIs as alternatives to common delegate protocols (`PushNotificationDelegate`, `DeepLinkDelegate`, etc.). The delegate pattern is still supported but will be deprecated in a future release.
- Refactored core Airship components to use protocols instead of concrete classes, improving testability and modularity. See migration guide for protocol renames and class-to-protocol conversions.
- Added support for split view in the Message Center, improving the layout on larger devices.
- Updated the Preference Center with a refreshed design and fixed UI issues on tvOS and visionOS.
- Fixed Package.swift to remove macOS as a supported platform.
- CustomViews within a Scene can now programmatically control their parent Scene, enabling more dynamic and interactive custom content.