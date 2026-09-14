
# iOS 21.x Changelog

[Migration Guides](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration)
[All Releases](https://github.com/urbanairship/ios-library/releases)

## Version 21.0.0 - September 14, 2026
SDK 21.0 splits the Scene/layout rendering engine out of `AirshipCore` into new modules, removes CocoaPods support, requires Xcode 27, brings on-device AI to Scenes and in-app experiences, includes a broad set of Scene layout fixes, and tightens the public API surface across modules. See the [Migration Guide](https://github.com/urbanairship/ios-library/blob/main/Documentation/Migration/migration-guide-20-21.md) for details.

### Changes
- Xcode 27 is now required to build the SDK.
- Removed CocoaPods support, ahead of [Trunk's specs repo going read-only in December](https://blog.cocoapods.org/CocoaPods-Specs-Repo/). Integrate via Swift Package Manager (recommended) or the prebuilt XCFrameworks.
- Tightened the public API surface across modules with `@_spi(AirshipInternal)`/`internal`, and Swift Package targets now use internal imports by default.
- Marked `AirshipUtils` `@_spi(AirshipInternal)` and removed its unused public helper methods.
- Removed the background-fetch app-integration method `AppIntegration.application(_:performFetchWithCompletionHandler:)` and its `UAAppIntegration` Objective-C equivalent.

#### On-Device AI
- Added on-device AI support for three usages: in-app message suppression, embedded view selection, and Scene text-input inference.
- Added an optional `AirshipFoundationModels` module that wires a built-in on-device model into those usages.
- Added the `AirshipFeature.onDeviceAI` privacy manager feature gating on-device AI.

#### Scenes
- Split the Scene rendering engine out of `AirshipCore` into new `AirshipSceneRenderer` and `AirshipScenes` modules. Embedded views and custom views now require `import AirshipScenes`.
- Added six `AirshipPermission` cases for the Composer's system-permission action.
- Fixed a broad set of Scene layout and sizing issues. Verify your live Scenes after upgrading.
- Fixed in-app message banners clipping or oscillating in width on rotation.
- Fixed background media cropping instead of filling behind an auto-height layout.
- Fixed a label's end icon pulling its `[icon, text, icon]` group off-center.
- Fixed Scene text line height to consistently use the scaled-font-size approximation.
- Fixed a Pager crash when a page list emptied out or restored state drifted from it.

#### Embedded Views
- Added `AirshipEmbeddedCarousel`, a carousel container for embedded content.
- Ordered `AirshipEmbeddedViewStyleConfiguration.pending` by selection preference.
- Added `filterInstances`, a closure to exclude specific pending instances from selection.
- Let `.instance` selection take an ordered list of instance IDs instead of just one.
- Fixed embedded views not reacting to a changed `embeddedID` or `selection`.

#### Message Center
- Removed `MessageCenterUser`, `MessageCenterInbox.user`, and `MessageCenterNativeBridgeExtension` from the public API, along with their Objective-C equivalents. Use the provided `MessageCenterMessageView`/`MessageCenterMessageContentView` UI instead.

#### Preference Center
- Marked `ChannelTextField`, `ErrorLabel`, and `AddChannelState` internal.

#### Feature Flags
- Changed `FeatureFlagManager.featureFlagStatusUpdates` to emit `FeatureFlagUpdateStatus` instead of `any Sendable`.

### Other Fixes
- Fixed `AirshipPrivacyManager.enableFeatures`/`disableFeatures` permanently baking a server-side feature disable into local storage.
- Fixed a crash handling malformed native-bridge `run-action-cb` URLs.
- Fixed a regex range mismatch that could misparse non-ASCII audience matches, device tokens, or URL allow-list patterns.
- Fixed the Core Data store's `-wal` and `-shm` files being left behind when the store file is deleted.

