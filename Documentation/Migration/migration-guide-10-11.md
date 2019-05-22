# Airship iOS SDK Migration Guide

# Airship Library 10.x to 11.0

This release makes a breaking change to the way the SDK manages location services.
The core SDK now contains no references to CoreLocation APIs, and the `UALocation`
module has been broken out into a separate framework, `AirshipLocationKit`. The module
itself remains largely unchanged, but apps using it must import and link against
`AirshipLocationKit` in order to access it. In place of the static `location` accessor
on `UAirship`, a `shared` accessor has been added to `UALocation` for retrieving the
singleton instance for the module.

In addition, a new protocol named
`UALocationProviderDelegate` has been added, along with an assignable delegate property on
`UAirship`, which maps to the `UALocation` module by default and which be overridden
with custom location providers in advanced use cases.

## UAirship

### Added

* `locationProviderDelegate`

### Removed

* `location`

## UALocation

### Added

* `shared`

## UALocationEvent

This class no longer requires references to `CoreLocation`, including `CLLocation` objects.
All methods previously requiring CLLocation objects have been changed to take `UALocationEventInfo`
objects, which encapsulate the relevant data.

### Added

* `locationEventWithInfo:providerType:desiredAccuracy:distanceFilter`
* `singleLocationEventWithInfo:providerType:desiredAccuracy:distanceFilter`
* `standardLocationEventWithInfo:providerType:desiredAccuracy:distanceFilter`
* `significantChangeLocationEventWithInfo:providerType`

### Removed

* `locationEventWithLocation:providerType:desiredAccuracy:distanceFilter`
* `singleLocationEventWithLocation:providerType:desiredAccuracy:distanceFilter`
* `standardLocationEventWithLocation:providerType:desiredAccuracy:distanceFilter`
* `significantChangeLocationEventWithLocation:providerType`

## UALocationProviderDelegate

This protocol is new as of 11.0, and the default implementation is found in the `UALocation` module
in `AirshipLocationKit`. The core SDK uses the protocol in order to negotiate location settings with
the `UALocation` module, as well as for reporting purposes. In advanced use cases, apps can override
the `locationProviderDelegate` property on `UAirship` to set a custom provider, which can then be
used in place of the `UALocation` module, while allowing features such as location reporting and
location-based In-App Automation audience conditions to function normally.

# Airship Library 10.x to 10.2

This release consists mostly of bugfixes and enhancements to In-App Automation, but some deprecations were made due
to changes in how the SDK accesses data in the Keychain.

## UAUserData

This class encapsulates all the relevant data associated with a `UAUser` instance, including the username,
password, and URL. The data is accessed asynchronously from the Keychain.

## UAUser

### Added

* `getUserData:`

### Deprecated (to be removed in SDK 11)

* `username`
* `password`
* `url`

Instead of using these properties, apps requiring access to the user data should call `getUserData:`, which
takes an asynchronous callback. While the above properties will continue to work in deprecation, they are
synchronous and potentially blocking, and so their use is discouraged. Any apps using these properties are strongly
recommended to use the new asynchronous getter.

## UAUtils

### Deprecated (to be removed in SDK 11)

* `deviceID`

As with the `UAUser` properties mentioned above, this property will continue to function in deprecation, but it
is similarly blocking and so its use is discouraged. In addition, as apps should not be using this data, as of SDK 11.0 it
will become an internal-only feature with no public replacement.

