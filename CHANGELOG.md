
# iOS 21.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)
[All Releases](https://github.com/urbanairship/ios-library/releases)

## Version 21.0.0-beta.1 - June 30, 2026
First beta of the 21.0.0 major release. This release splits the Scene/layout rendering engine out of `AirshipCore` into new modules and removes CocoaPods support. See the [Migration Guide](https://github.com/urbanairship/ios-library/blob/main/Documentation/Migration/migration-guide-20-21.md) for details.

### Changes
- Split the Scene rendering engine out of `AirshipCore` into the new `AirshipSceneRenderer` and `AirshipScenes` modules. Embedded views and custom views now require `import AirshipScenes`. No package changes are needed for Swift Package Manager; manual XCFramework/Carthage integrations must add the new frameworks.
- Removed CocoaPods support. Integrate via Swift Package Manager (recommended) or the prebuilt XCFrameworks.
- Xcode 27 will be required for the final 21.0 release.
- Tightened the public API surface: internal-only helpers that were unintentionally exposed are now `internal` or `@_spi(AirshipInternal)`.
- Removed public `AirshipUtils` helper methods: `compareVersion(_:toVersion:maxVersionParts:)`, `hasNetworkConnection()`, `deviceModelName()`, and `mergeFetchResults(_:)`.
- Removed the background-fetch app-integration method `AppIntegration.application(_:performFetchWithCompletionHandler:)` and its `UAAppIntegration` Objective-C equivalent. `UIApplicationDelegate.application(_:performFetchWithCompletionHandler:)` was deprecated by Apple in iOS 13; use background push or `BGAppRefreshTask` instead.

