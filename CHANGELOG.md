
# iOS 21.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)
[All Releases](https://github.com/urbanairship/ios-library/releases)

## Version 21.0.0-beta.2 - July 17, 2026
Second beta of the 21.0.0 major release. This release continues tightening the public API surface and adds targeting and Live Activity improvements. See the [Migration Guide](https://github.com/urbanairship/ios-library/blob/main/Documentation/Migration/migration-guide-20-21.md) for details.

### Changes
- Message Center: removed the user credentials and message native bridge from the public API — `MessageCenterUser`, the `user` property on `MessageCenterInbox`, and `MessageCenterNativeBridgeExtension`, along with the Objective-C equivalents (`UAMessageCenterUser`, `UAMessageCenterInbox.getUser()`, and `UAMessageCenterNativeBridge`). Display messages through `MessageCenterMessageView` or `MessageCenterMessageContentView`, which resolve web vs. native content and handle authentication.
- Preference Center: the `ChannelTextField` and `ErrorLabel` views and the `AddChannelState` enum are now `internal`.
- `AirshipUtils` is now `internal` and no longer part of the public API.
- Feature Flags: `FeatureFlagManager.featureFlagStatusUpdates` now emits `FeatureFlagUpdateStatus` instead of `any Sendable`.
- Embedded Views: `AirshipEmbeddedView` now takes an `AirshipEmbeddedSelection` to control which pending item is displayed — `.priority` (default) or target a specific pending instance by its `instanceID`. The comparator-based initializer is deprecated.
- Live Activities: `Activity.airshipWatchActivities` gained a `unique` option to invoke the tracking block at most once per Live Activity.
- In-App Automation: the default display coordinator now blocks while an immediate message is displaying, and delay-cancellation triggers are no longer swallowed while a schedule is in the triggered state.
- Continued to tighten the public API surface across modules (`@_spi(AirshipInternal)`/`internal`), and Swift Package targets now use internal imports by default.
- Added a new optional, experimental on-device AI module, `AirshipAIModels`, built on Apple's Foundation Models. This is early groundwork — there is no supported feature that uses it yet, the API may change, and it can be left out of your integration for now.

## Version 21.0.0-beta.1 - June 30, 2026
First beta of the 21.0.0 major release. This release splits the Scene/layout rendering engine out of `AirshipCore` into new modules and removes CocoaPods support. See the [Migration Guide](https://github.com/urbanairship/ios-library/blob/main/Documentation/Migration/migration-guide-20-21.md) for details.

### Changes
- Split the Scene rendering engine out of `AirshipCore` into the new `AirshipSceneRenderer` and `AirshipScenes` modules. Embedded views and custom views now require `import AirshipScenes`. No package changes are needed for Swift Package Manager; manual XCFramework/Carthage integrations must add the new frameworks.
- Removed CocoaPods support. Integrate via Swift Package Manager (recommended) or the prebuilt XCFrameworks.
- Xcode 27 will be required for the final 21.0 release.
- Tightened the public API surface: internal-only helpers that were unintentionally exposed are now `internal` or `@_spi(AirshipInternal)`.
- Removed public `AirshipUtils` helper methods: `compareVersion(_:toVersion:maxVersionParts:)`, `hasNetworkConnection()`, `deviceModelName()`, and `mergeFetchResults(_:)`.
- Removed the background-fetch app-integration method `AppIntegration.application(_:performFetchWithCompletionHandler:)` and its `UAAppIntegration` Objective-C equivalent. `UIApplicationDelegate.application(_:performFetchWithCompletionHandler:)` was deprecated by Apple in iOS 13; use background push or `BGAppRefreshTask` instead.

