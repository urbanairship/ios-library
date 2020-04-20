# Airship iOS SDK Migration Guide

# Airship SDK 13.0 and 13.1 to 13.2

Airship SDK 13.2 is a minor update that makes a few non-breaking changes to the Message Center and Custom Event APIs.

## Message Center Changes

The default Message Center view controllers have been overhauled to improve code quality and readability. Because
this involves some changes to the public APIs, rather than replacing them outright, the following classes and
protocols are marked deprecated as of SDK 13.2:

### Deprecated

* `UAMessageCenterSplitViewController`
* `UAMessageCenterListViewController`
* `UAMessageCenterMessageViewController`
* `UAMessageCenterMessageViewProtocol`

Instead of the deprecated controller classes, migrated integrations should use the following:

### Added

* `UADefaultMessageCenterSplitViewController`
* `UADefaultMessageCenterListViewController`
* `UADefaultMessageCenterMessageViewController`

SDK 13.2 also adds new protocols to make it easier to create custom interfaces with these controllers. Objects can sign up
as delegates for the default list view and message view controllers, in order to receive callbacks related to user message selections and
message loading operations.

### Added

* `UAMessageCenterListViewDelgate`
* `UAMessageCenterMessageViewDelegate`

## Custom Event Changes

The type-specific property setters in the Custom Event API have been deprecated in favor of a single property on `UACustomEvent`, named `properties`.
This property takes an `NSDictionary` mapping key strings to boolean, string, number, or string array values.

### Deprecated

* `setBoolProperty:forKey:`
* `setStringProperty:forKey:`
* `setNumberProperty:forKey:`
* `setStringArrayProperty:forKey:`

### Added

* `@property (nonatomic, copy) NSDictionary *properties`
