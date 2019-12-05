# Airship iOS SDK Migration Guide

# Airship SDK 12.x to 13.0

Airship SDK 13 is a major update that splits the SDK into modules. In basic integration scenarios,
apps can continue to use a single Airship framework, but as of SDK 13 it is now possible to create
custom integrations by selecting feature modules. Most of the changes in this release reflect
the restructuring that makes this possible.

## Framework Changes

### Renamed SDK frameworks and new submodules

`AirshipKit.framework` has been replaced with `Airship.framework`. This framework contains all the SDK
features, with the exception of location which remains an explicit opt-in. The core SDK and feature
module frameworks are as follows:

* `AirshipCore.framework`
* `AirshipMessageCenter.framework`
* `AirshipAutomaton.framework`
* `AirshipLocation.framework`
* `AirshipExtendedActions.framework`

The renaming of `AirshipKit.framework` means that imports for the basic use case have changed. To import
the full SDK in one step:

Objective-c:
```objective-c
@import Airship;
```

Swift:
```swift
import Airship
```

### Location must be used with explicit submodules

AirshipLocation is an explicit opt-in, so that apps with no need for location services do not need to
include location description strings when submitting to Apple. Because of this, AirshipLocation not
compatible with `Airship.framework`, and must be imported alongside the core SDK and explicit feature
modules. If your app is using location, the imports should look like the following:

Objective-c:
```objective-c
@import AirshipCore;
@import AirshipLocation;

// Include these for access to message center, automation and extended actions
@import AirshipMessageCenter;
@import AirshipAutomation;
@import AirshipExtendedActions;
```

Swift:
```swift
import AirshipCore
import AirshipLocation

// Include these for access to message center, automation and extended actions
import AirshipMessageCenter
import AirshipAutomation
import AirshipExtendedActions
```

### Extensions

The `AirshpAppExtensions.framework` has been renamed to `AirshipExtensionsFramework`. Additionally, the
class `UAMediaContentExtension` has been renamed to `UANotificationServiceExtension`. The functionality
of the class remains the same, but app extensions subclassing this will need to be updated to use the new class
name.

## Shared Accessor Changes

Shared accessors for functionality such as Message Center and In-App Automation have changed from static
methods on `UAirship` to singletons with a standardized `shared` method.

### Removed from UAirship

* `messageCenter`
* `inAppMessageManager`

### Removed from UALocation

* `sharedLocation`

### Added

* `UAMessageCenter shared`
* `UAInAppMessageManager shared`
* `UALocation shared`

Objective-c:
```objective-c
[UAMessageCenter shared]
[UAInAppMessageManager shared]
[UALocation shared]
```

Swift:
```swift
UAMessageCenter.shared()
UAInAppMessageManager.shared()
UALocation.shared()
```

## Resource bundle changes

SDK 13 no longer has a dedicated resource bundle, but instead packages resources with their respective modules.
To access the bundle containing the resources for a particular module, special classes have been added that provide
accessors for each module.

### Removed from UAirship

* `resources`

### Added

* `UAirshipCoreResources bundle`
* `UAMessageCenterResources bundle`
* `UAAutomationResources bundle`
* `UAExtendedActionsResources bundle`

Objective-c:
```objective-c
[UAirshipCoreResources bundle]
[UAMessageCenterResources bundle]
[UAAutomationResources bundle]
[UAExtendedActionsResources bundle]
```

Swift:
```swift
UAirshipCoreResources.bundle()
UAMessageCenterResources.bundle()
UAAutomationResources.bundle()
UAExtendedActionsResources.bundle()
```

## Message Center changes

The Message Center codebase has been refactored in order to better support modularization. This includes the removal
of some legacy classes, such as `UAInbox`, and a new protocol for Message Center UI, `UAMessageCenterDisplayDelegate`,
that makes it easier to build custom interfaces that work more seamlessly with the Message Center module. In place of
`UAInbox`, `UAMessageCenter` provides access to objects such as the message list. Much of the out-of-the-box UI
functionality previously cointained in `UAMessageCenter` is now part of a new class, `UADefaultMessageCenterUI`.

### Removed

* `UAInbox`
* `UAInboxDelegate`

### Added

* `UADefaultMessageCenterUI`
* `UAMessageCenterDisplayDelegate`

### Migrating UAInboxDelegate protocol methods to UAMessageCenterDisplayDelegate protocol

* `showInbox`
    * Use `displayMessageCenterAnimated:`
* `richPushMessageAvailable`
    * No equivalent in UAMessageCenterDisplayDelegate
* `showMessageForID:`
    * Use `displayMessageCenterForMessageID:animated:`

### Displaying the default Message Center

The methods `display` and `display:(BOOL)animated:` remain in `UAMessageCenter`, which normally display the default
UI. However, the default UI functionality is now delegated to `UADefaultMessageCenterUI` class, which implements the
`UAMessageCenterDisplayDelegate` protocol. This means that if you set a custom display delegate on `UAMessageCenter`,
the display methods in `UAMessageCenter` will delegate to your class instead of the default UI.
