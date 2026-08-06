
# iOS 21.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)
[All Releases](https://github.com/urbanairship/ios-library/releases)

## Version 21.0.0-beta.2 - August 5, 2026
Second beta of the 21.0.0 major release. This release requires Xcode 27, continues tightening the public API surface, and adds a new experimental on-device AI module. See the [Migration Guide](https://github.com/urbanairship/ios-library/blob/main/Documentation/Migration/migration-guide-20-21.md) for details.

### Changes
- Xcode 27 is now required to build the SDK.
- Message Center: removed the user credentials and message native bridge from the public API — `MessageCenterUser`, the `user` property on `MessageCenterInbox`, and `MessageCenterNativeBridgeExtension`, along with the Objective-C equivalents (`UAMessageCenterUser`, `UAMessageCenterInbox.getUser()`, and `UAMessageCenterNativeBridge`). Display messages through `MessageCenterMessageView` or `MessageCenterMessageContentView`, which resolve web vs. native content and handle authentication.
- Preference Center: the `ChannelTextField` and `ErrorLabel` views and the `AddChannelState` enum are now `internal`.
- `AirshipUtils` is now `internal` and no longer part of the public API.
- Feature Flags: `FeatureFlagManager.featureFlagStatusUpdates` now emits `FeatureFlagUpdateStatus` instead of `any Sendable`.
- Continued to tighten the public API surface across modules (`@_spi(AirshipInternal)`/`internal`), and Swift Package targets now use internal imports by default.
- Added a new optional, experimental on-device AI module, `AirshipAIModels`, built on Apple's Foundation Models. Linking it registers a built-in on-device model on iOS 26. On iOS 27 you can also route evaluations to any Foundation Models `LanguageModel` with `AirshipFoundationModel.backed(by:)`, or to Apple's Private Cloud Compute model with `AirshipFoundationModel.privateCloudCompute()`. Embedded view selection is usable today — pass `AirshipEmbeddedSelection.ai(config:fallback:)` to `AirshipEmbeddedView` and the model picks which pending instance to display, falling back to priority, a comparator, or a specific instance when it's unavailable or has no opinion. Two further usages are wired up and activate from the message payload: in-app message suppression and Scene text-input inference. Host apps supply context per usage with `Airship.ai.setContextProvider(for:_:)` and can route usages to different backends with `Airship.ai.setModelResolver(_:)`.

## Version 21.0.0-beta.1 - June 30, 2026
First beta of the 21.0.0 major release. This release splits the Scene/layout rendering engine out of `AirshipCore` into new modules and removes CocoaPods support. See the [Migration Guide](https://github.com/urbanairship/ios-library/blob/main/Documentation/Migration/migration-guide-20-21.md) for details.

### Changes
- Split the Scene rendering engine out of `AirshipCore` into the new `AirshipSceneRenderer` and `AirshipScenes` modules. Embedded views and custom views now require `import AirshipScenes`. No package changes are needed for Swift Package Manager; manual XCFramework/Carthage integrations must add the new frameworks.
- Removed CocoaPods support. Integrate via Swift Package Manager (recommended) or the prebuilt XCFrameworks.
- Xcode 27 will be required for the final 21.0 release.
- Tightened the public API surface: internal-only helpers that were unintentionally exposed are now `internal` or `@_spi(AirshipInternal)`.
- Removed public `AirshipUtils` helper methods: `compareVersion(_:toVersion:maxVersionParts:)`, `hasNetworkConnection()`, `deviceModelName()`, and `mergeFetchResults(_:)`.
- Removed the background-fetch app-integration method `AppIntegration.application(_:performFetchWithCompletionHandler:)` and its `UAAppIntegration` Objective-C equivalent. `UIApplicationDelegate.application(_:performFetchWithCompletionHandler:)` was deprecated by Apple in iOS 13; use background push or `BGAppRefreshTask` instead.

