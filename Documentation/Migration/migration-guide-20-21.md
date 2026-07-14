# Airship iOS SDK 20.x to 21.0 Migration Guide

SDK 21.0 continues the modularization of the Airship SDK. The scene/layout
rendering engine has been split out of `AirshipCore` into two new modules,
`AirshipSceneRenderer` and `AirshipScenes`. CocoaPods support has been removed, and
the toolchain requirement moves to Xcode 27. This guide outlines the changes
required to migrate an app from SDK 20.x to SDK 21.0.

> **Note**
> This guide is a work in progress and will be updated as SDK 21.0 development
> continues.

**Required Migration Tasks:**
- Update to Xcode 27 (required for the final 21.0 release).
- Migrate off CocoaPods to Swift Package Manager (or manual XCFramework/Carthage integration).
- Update `import` statements for embedded views and custom views.

**Optional Migration Tasks:**
- Replace deprecated APIs with their recommended alternatives.

## Table of Contents

- [Requirements](#requirements)
- [Dependency Manager Changes](#dependency-manager-changes)
  - [CocoaPods Removed](#cocoapods-removed)
  - [Swift Package Manager](#swift-package-manager)
  - [XCFrameworks / Carthage](#xcframeworks--carthage)
- [Import Changes](#import-changes)
  - [Embedded Views](#embedded-views)
  - [Custom Views](#custom-views)
- [Hidden APIs](#hidden-apis)
- [Removed APIs](#removed-apis)
- [Troubleshooting](#troubleshooting)

## Requirements

The final SDK 21.0 release will require **Xcode 27**. Xcode 26 may still build
against current pre-release versions, but this is not guaranteed going forward —
plan to update your build environment (including CI) to Xcode 27 before the final
21.0 release.

## Dependency Manager Changes

### CocoaPods Removed

**CocoaPods is no longer supported in SDK 21.0.** The `Airship.podspec` and
`AirshipServiceExtension.podspec` files have been removed, and no new podspecs
will be published.

CocoaPods is being sunset (the Trunk service and CDN are shutting down at the end
of 2026), and we cannot commit to supporting it for the full lifetime of SDK 21.
If your project integrates Airship via CocoaPods, you must migrate to **Swift
Package Manager** (recommended), or integrate the prebuilt **XCFrameworks**
manually / via Carthage.

### Swift Package Manager

Swift Package Manager is the recommended integration method. If you are coming
from CocoaPods, remove the Airship pods from your `Podfile` and add the package in
Xcode (**File → Add Package Dependencies…**) using the repository URL, then add
the products you need to your target.

```
https://github.com/urbanairship/ios-library.git
```

**There are no new products to add for SPM.** The scene-rendering code is bundled
into the products you already use — `AirshipScenes` ships as part of
`AirshipAutomation` and `AirshipMessageCenter`, so it comes in automatically. The
list of products you add to your target (`AirshipCore`, `AirshipAutomation`,
`AirshipMessageCenter`, `AirshipPreferenceCenter`, `AirshipFeatureFlags`,
`AirshipObjectiveC`, `AirshipNotificationServiceExtension`) is unchanged.

The only change for SPM users is in your source code: add `import AirshipScenes`
where you use embedded views or custom views (see [Import Changes](#import-changes)).

### XCFrameworks / Carthage

If you integrate the prebuilt XCFrameworks directly (or via Carthage), SDK 21.0
ships **two new frameworks** that you must add to your project:

- `AirshipSceneRenderer.xcframework`
- `AirshipScenes.xcframework`

These have been factored out of `AirshipCore`, so embedding `AirshipCore`,
`AirshipAutomation`, or `AirshipMessageCenter` alone is no longer sufficient — the
app will fail to link without the new frameworks. Add and embed the frameworks
respecting the dependency order:

| Framework | Depends on |
|---|---|
| `AirshipBasement` | — |
| `AirshipCore` | `AirshipBasement` |
| `AirshipSceneRenderer` | `AirshipBasement` |
| `AirshipScenes` | `AirshipCore`, `AirshipSceneRenderer` |
| `AirshipAutomation` | `AirshipCore`, `AirshipScenes` |
| `AirshipMessageCenter` | `AirshipCore`, `AirshipScenes` |

In short: if you embed `AirshipAutomation` or `AirshipMessageCenter`, you must also
embed `AirshipScenes` and `AirshipSceneRenderer` (and their transitive
dependencies).

## Import Changes

The scene-rendering engine has moved out of `AirshipCore` into the new
`AirshipScenes` module. For most internal types this is invisible, but two sets of
**public, customer-facing APIs** moved and now require an additional import:
**embedded views** and **custom views**.

`AirshipCore` does not re-export these symbols, so any file that uses them must add
`import AirshipScenes`. The APIs themselves (types, properties, and access patterns
such as `AirshipCustomViewManager.shared`) are unchanged — only the import differs.

### Embedded Views

Affected public symbols: `AirshipEmbeddedView`, `AirshipEmbeddedInfo`,
`AirshipEmbeddedSize`, `AirshipEmbeddedObserver`, `AirshipEmbeddedContentView`,
`AirshipEmbeddedViewStyle`, `AirshipEmbeddedViewStyleConfiguration`,
`DefaultAirshipEmbeddedViewStyle`, the `setAirshipEmbeddedStyle(_:)` view modifier,
and `AirshipViewSizeReader`.

**Before:**
```swift
import AirshipCore

struct MyView: View {
    var body: some View {
        AirshipEmbeddedView(embeddedID: "promo") {
            ProgressView()
        }
    }
}
```

**After:**
```swift
import AirshipCore
import AirshipScenes   // <- add this

struct MyView: View {
    var body: some View {
        AirshipEmbeddedView(embeddedID: "promo") {
            ProgressView()
        }
    }
}
```

### Custom Views

Affected public symbols: `AirshipCustomViewManager`, `AirshipCustomViewArguments`,
and the `AirshipCustomViewBuilder` typealias.

**Before:**
```swift
import AirshipCore

AirshipCustomViewManager.shared.register(name: "weather") { args in
    WeatherView(args: args)
}
```

**After:**
```swift
import AirshipScenes   // <- AirshipCustomViewManager moved here

AirshipCustomViewManager.shared.register(name: "weather") { args in
    WeatherView(args: args)
}
```

## Hidden APIs

SDK 21.0 formalizes the boundary between the supported public API and SDK
internals. Symbols that were technically `public` but were always documented as
internal-only (`/// - Note: For internal use only. :nodoc:`) have been moved
behind `@_spi(AirshipInternal)` or marked `internal`. This cleanup spans all
modules. These symbols were never part of the supported API, and no remaining
public APIs were renamed or had signature changes as part of this cleanup. Most
apps will not be affected.

If your app happened to use one of these internal symbols (for example the
SwiftUI convenience helpers like `airshipApplyIf(_:transform:)` or the `Color`
hex initializer, or one of the internal utility classes), copy the small helper
into your own codebase rather than relying on it from the SDK. Alternatively,
[open an issue](https://github.com/urbanairship/ios-library/issues) describing
your use case — if it's something other apps need, we may expose it as a
supported API.

## Removed APIs

A handful of utility and app-integration methods that were unintentionally public
— or that wrapped Apple APIs deprecated years ago — have been removed. None had a
supported public use; replacements are noted below where relevant.

### AirshipUtils helpers

The following `AirshipUtils` methods have been removed: `compareVersion(_:toVersion:maxVersionParts:)`,
`hasNetworkConnection()`, `deviceModelName()`, and `mergeFetchResults(_:)`. These
were internal utilities that were unintentionally exposed and have no public
replacement — implement the equivalent in your own code if you depended on one.

### Background-fetch app integration

`AppIntegration.application(_:performFetchWithCompletionHandler:)` and its
`UAAppIntegration` Objective-C equivalent have been removed. They forwarded
`UIApplicationDelegate.application(_:performFetchWithCompletionHandler:)`, which
Apple deprecated in iOS 13. Remove the corresponding call from your app delegate;
use background push or a `BGAppRefreshTask` (BackgroundTasks framework) instead.

### Message Center user credentials and native bridge

The Message Center user credentials and the message native bridge are no longer
exposed: `MessageCenterUser`, the `user` property on `MessageCenterInbox`, and
`MessageCenterNativeBridgeExtension` have been removed from the public API, along
with the Objective-C equivalents (`UAMessageCenterUser`,
`UAMessageCenterInbox.getUser()`, and `UAMessageCenterNativeBridge`).

These existed to load a message's `bodyURL` directly in your own web view,
authenticating the request with the user's basic auth string. That flow is no
longer supported. Message Center messages are no longer limited to web content —
a message can also be delivered as a native (Scenes) layout. The `bodyURL` is an
internal detail: for native messages it does not point to renderable web content,
so loading it in a web view silently breaks for those messages. Future inbox
changes will also use a different authentication scheme for messages.

Display messages through the Airship-provided views instead, which resolve the
content type and handle authentication for both web and native messages:

- `MessageCenterMessageView(messageID:dismissAction:)` — the full message view,
  including loading indicator, error/retry UI, and mark-as-read behavior. Styleable
  via `messageViewStyle(_:)`.
- `MessageCenterMessageContentView(viewModel:phase:dismissAction:)` — renders only
  the message content, reporting its loading state through the `phase` binding so
  you can build fully custom chrome (your own loading, error, and retry UI) around
  it.

### Preference Center view components

The `ChannelTextField` and `ErrorLabel` SwiftUI views and the `AddChannelState`
enum are now internal. These were building blocks of the Preference Center's
add-channel (SMS/email opt-in) prompt and were unintentionally public. If you
embedded them in your own UI, replace them with your own implementations.

## Troubleshooting

**"Cannot find 'AirshipEmbeddedView' / 'AirshipCustomViewManager' in scope"**
- Add `import AirshipScenes` to the file. These types moved out of `AirshipCore`.
- No package/product changes are needed for SPM — `AirshipScenes` already ships
  with `AirshipAutomation` and `AirshipMessageCenter`.

**Linker errors after upgrading XCFrameworks / Carthage**
- Add and embed the new `AirshipSceneRenderer.xcframework` and
  `AirshipScenes.xcframework`, respecting the dependency table above.

**CocoaPods install fails / Airship pods not found**
- CocoaPods is no longer supported. Migrate to Swift Package Manager or manual
  XCFramework integration.

**"Cannot find type … in scope" for a type that was public in 20.x**
- Internal-only (`:nodoc:`) types are now `@_spi(AirshipInternal)` or `internal`.
  See [Hidden APIs](#hidden-apis) — reimplement the helper in your own code, or
  open an issue if you have a use case for a supported API.

### Getting Help

If you encounter issues not covered in this guide:
- Check the [Airship Documentation](https://docs.airship.com/)
- Review the [SDK API Reference](https://docs.airship.com/reference/libraries/ios/)
- Contact [Airship Support](https://support.airship.com/)
