
# iOS 21.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)
[All Releases](https://github.com/urbanairship/ios-library/releases)

## Version 21.0.0-beta.2 - August 27, 2026
Second beta of the 21.0.0 major release. This release requires Xcode 27, brings on-device AI to Scenes and in-app experiences, includes a broad set of Scene layout fixes, and continues tightening the public API surface. See the [Migration Guide](https://github.com/urbanairship/ios-library/blob/main/Documentation/Migration/migration-guide-20-21.md) for details.

### Changes
- Xcode 27 is now required to build the SDK.
- Scenes: a broad set of layout and sizing fixes across the rendering engine. Existing Scenes may lay out differently than they did in 20.x; verify your live Scenes after upgrading.
- In-App Automation: display limits are now calculated from the ledger, with retention and compaction, and a concurrency fix for shared display limits.
- Message Center: removed the user credentials and message native bridge from the public API — `MessageCenterUser`, the `user` property on `MessageCenterInbox`, and `MessageCenterNativeBridgeExtension`, along with the Objective-C equivalents (`UAMessageCenterUser`, `UAMessageCenterInbox.getUser()`, and `UAMessageCenterNativeBridge`). Display messages through `MessageCenterMessageView` or `MessageCenterMessageContentView`, which resolve web vs. native content and handle authentication.
- Preference Center: the `ChannelTextField` and `ErrorLabel` views and the `AddChannelState` enum are now `internal`.
- `AirshipUtils` is now `internal` and no longer part of the public API.
- Feature Flags: `FeatureFlagManager.featureFlagStatusUpdates` now emits `FeatureFlagUpdateStatus` instead of `any Sendable`.
- Continued to tighten the public API surface across modules (`@_spi(AirshipInternal)`/`internal`), and Swift Package targets now use internal imports by default.
- On-device AI: a new optional module, `AirshipFoundationModels`, lets you wire an on-device model into the SDK and put it to work across three usages — in-app message suppression, embedded view selection, and Scene text-input inference. The framework ships in `AirshipCore` and no-ops until you configure a model, so nothing changes unless you opt in. Linking the module registers Apple's on-device model on iOS 26; prompts and context stay on the device. See [On-device AI](https://www.airship.com/docs/developer/sdk-integration/apple/on-device-ai) for setup, context providers, and model routing.
- On-device AI is gated by a new privacy manager feature, `AirshipFeature.onDeviceAI`. It is included in `.all`, but apps that enable an explicit set of features must add it or `Airship.ai` will behave as though no model were configured.

## Version 21.0.0-beta.1 - June 30, 2026
First beta of the 21.0.0 major release. This release splits the Scene/layout rendering engine out of `AirshipCore` into new modules and removes CocoaPods support. See the [Migration Guide](https://github.com/urbanairship/ios-library/blob/main/Documentation/Migration/migration-guide-20-21.md) for details.

### Changes
- Split the Scene rendering engine out of `AirshipCore` into the new `AirshipSceneRenderer` and `AirshipScenes` modules. Embedded views and custom views now require `import AirshipScenes`. No package changes are needed for Swift Package Manager; manual XCFramework/Carthage integrations must add the new frameworks.
- Removed CocoaPods support. Integrate via Swift Package Manager (recommended) or the prebuilt XCFrameworks.
- Xcode 27 will be required for the final 21.0 release.
- Tightened the public API surface: internal-only helpers that were unintentionally exposed are now `internal` or `@_spi(AirshipInternal)`.
- Removed public `AirshipUtils` helper methods: `compareVersion(_:toVersion:maxVersionParts:)`, `hasNetworkConnection()`, `deviceModelName()`, and `mergeFetchResults(_:)`.
- Removed the background-fetch app-integration method `AppIntegration.application(_:performFetchWithCompletionHandler:)` and its `UAAppIntegration` Objective-C equivalent. `UIApplicationDelegate.application(_:performFetchWithCompletionHandler:)` was deprecated by Apple in iOS 13; use background push or `BGAppRefreshTask` instead.

