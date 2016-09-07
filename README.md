# iOS Urban Airship Library

## Overview

Urban Airship's libUAirship is a drop-in static library that provides a simple way to
integrate Urban Airship services into your iOS applications. If you want to
include the library in your app, you can download ``libUAirship-latest.zip`` from
[Developer Resources](http://urbanairship.com/resources/developer-resources). This zip
contains a pre-compiled universal library for armv7/armv7s/arm64/i386/x86_64 (`libUAirship-x.y.z.a`)
as well as the subproject necessary for building AirshipKit.

## iOS 8 Notes (Updated Aug 12, 2015)

Known issues with iOS 8.0.0 that may impact your application:
- Applications do not enter the 'active' state when started from an interactive notification
and subsequent app sessions do not receive the application:didBecomeActive delegate call or
UIApplicationDidBecomeActiveNotification notification. The application state never
transitions out of 'inactive' (Radar #18179525). This will impact the accuracy of
reporting for applications using interactive notifications.
- Background refresh always appears to be enabled in an application even when disabled in
settings and background push will not be delivered. Push registration will consider a
device in this situation able to receive a background notification when it cannot. (Radar #18298439)
- **Resolved in iOS 10** Registering for UIUserNotificationTypeNone will prevent a re-registration until the device
has been restarted and the settings are manually updated in Settings.app. There is a
workaround for this issue in UA SDK 5.0.0. (Radar #17878212).
- **Resolved in iOS 9** The boolean properties on UIUserNotificationAction are mutated in the
UIUserNotificationCategory isEqual: method, so the authorizationRequired and destructive
properties on an action may receive values from actions in other categories
in the set registered with iOS. You may see notification actions with the wrong color
or authorization required status (Radar #18385104).

## Resources

- [Urban Airship iOS Library Reference](http://docs.urbanairship.com/reference/libraries/ios/latest/)
- [Getting started guide](http://docs.urbanairship.com/build/ios.html)
- [Library Upgrade Guides](http://docs.urbanairship.com/topic_guides/ios_migration.html)

## Quickstart

Xcode 8.0+ is required for all projects and the static library. Projects must target >= iOS8.

[Download](https://bintray.com/urbanairship/iOS/urbanairship-sdk/_latestVersion) and unzip the latest
version of libUAirship. If you are using one of our sample projects, copy the ``Airship`` directory
into the same directory as your project::

```sh
    cp -r Airship /SomeDirectory/ (where /SomeDirectory/YourProject/ is your project)
```

If you are not using a sample project, you'll need to import the source files for the User
Interface into your project. These are located under Airship/UI/Default. Ensure *UAirship.h* and
*UAPush.h* are included in your source files.

Modules are enabled by default in new projects starting with Xcode 5. We recommend enabling
modules and the automatic linking of frameworks. In the project's Build Settings, search for
``Enable Modules`` and set it to ``YES`` then set ``Link Frameworks Automatically`` to ``YES``.

New applications with iOS 8 or above as a deployment target may opt to link against AirshipKit.framework
instead of libUAirship. Because AirshipKit is an embedded framework as opposed to a static library,
applications using this framework can take advantage of features such as module-style import and automatic
bridging to the Swift language. Be aware, however, that embedded frameworks are not supported on iOS 7 and
below. Further instructions on how to set up AirshipKit can be found below under the header "AirshipKit Setup"


### Static Library Setup

- Add the Airship directory to your build target's header search path.

- Add `-ObjC -lz -lsqlite3` linker flag to *Other Linker Flags* to prevent "Selector Not Recognized"
runtime exceptions and to include linkage to libz and libsqlite3. The linker flag `-force_load <path to
library>/libUAirship-<version>.a` may be used in instances where using the -ObjC linker flag is undesirable.

- Link against the static library, add the libUAirship.a file to the Link Binary With Libraries section in the Build Phases tab for your target.

### AirshipKit Setup

- Include AirshipKit as a project dependency by dragging AirshipKit.xcodeproj out of the AirshipKit folder and into your app project in Xcode (directly under the top level of the project structure). Now AirshipKit will be built at compile-time for the active architecture.

- Link against the embedded framework by adding the AirshipKit.framework file to the Embedded Binaries section in the `General` tab for your target. This should also add it to the Linked Frameworks and Libraries section.

- Add the bridging header located in Airship/UI, named "UA-UI-Bridging-Header.h" to use the sample UI.


### Notification Service Extension
In order to take advantage of iOS 10 notification attachments, you will need to create a notification service extension
alongside your main application. Most of the work is already done for you, but since this involves creating a new target there
are a few additional steps:

* Create a new iOS target in Xcode and select the "Notification Service Extension" type
* Drag the new AirshipAppExtensions.framework into your app project
* Link against AirshipAppExtensions.framework in your extension's Build Phases
* Add a Copy Files phase for AirshipAppExtensions.framework and select "Frameworks" as the destination
* Delete all dummy source code for your new extension
* Import `<AirshipAppExtensions/AirshipAppExtensions.h>` if using Objective-C, or `AirshipAppExtensions` if using Swift, in `NotificationService`
* Inherit from `UAMediaAttachmentExtension` in `NotificationService`

#### Adding an Airship Config File

The library uses a .plist configuration file named `AirshipConfig.plist` to manage your production and development
application profiles. Example copies of this file are available in all of the sample projects. Place this file
in your project and set the following values to the ones in your application at http://go.urbanairship.com.  To
view all the possible keys and values, see the [UAConfig class reference](http://docs.urbanairship.com/reference/libraries/ios/latest/Classes/UAConfig.html)

You can also edit the file as plain-text:

```xml
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>detectProvisioningMode</key>
      <true/>
      <key>developmentAppKey</key>
      <string>Your Development App Key</string>
      <key>developmentAppSecret</key>
      <string>Your Development App Secret</string>
      <key>productionAppKey</key>
      <string>Your Production App Key</string>
      <key>productionAppSecret</key>
      <string>Your Production App Secret</string>
    </dict>
    </plist>
```

The library will auto-detect the production mode when setting `detectProvisioningMode` to `true`.

Advanced users may add scripting or preprocessing logic to this .plist file to automate the switch from
development to production keys based on the build type.

#### App Delegate additions

To enable push notifications, you will need to make several additions to your application delegate.

```obj-c
    - (BOOL)application:(UIApplication *)application
            didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

        // Your other application code.....

        // Set log level for debugging config loading (optional)
        // It will be set to the value in the loaded config upon takeOff
        [UAirship setLogLevel:UALogLevelTrace];

        // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
        // or set runtime properties here.
        UAConfig *config = [UAConfig defaultConfig];

        // You can then programmatically override the plist values:
        // config.developmentAppKey = @"YourKey";
        // etc.

        // Call takeOff (which creates the UAirship singleton)
        [UAirship takeOff:config];

        // Print out the application configuration for debugging (optional)
        UA_LDEBUG(@"Config:\n%@", [config description]);

        // Set the icon badge to zero on startup (optional)
        [[UAirship push] resetBadge];

        // User notifications will not be enabled until userPushNotificationsEnabled is
        // set YES on UAPush. Once enabled, the setting will be persisted and the user
        // will be prompted to allow notifications. You should wait for a more appropriate
        // time to enable push to increase the likelihood that the user will accept
        // notifications.
        // [UAirship push].userPushNotificationsEnabled = YES;

        return YES;
    }
```

To enable push later on in your application:

```obj-c
    // Somewhere in the app, this will enable push (setting it to NO will disable push,
    // which will trigger the proper registration or de-registration code in the library).
    [UAirship push].userPushNotificationsEnabled = YES;
```

## Logging

Logging can be configured through either the AirshipConfig.plist file or directly in code. The
default log level for production apps is `UALogLevelError` and the default for development apps
is `UALogLevelDebug`.

In `AirshipConfig.plist`, set `LOG_LEVEL` to one of the following integer values:

```obj-c
    None = 0
    Error = 1
    Warn = 2
    Info = 3
    Debug = 4
    Trace = 5
```

To set the log level in code, call `setLogLevel` after `takeOff`:

```obj-c
    [UAirship setLogLevel:UALogLevelWarn];
```

The available log levels are:

```obj-c
    UALogLevelNone
    UALogLevelError
    UALogLevelWarn
    UALogLevelInfo
    UALogLevelDebug
    UALogLevelTrace
```

Logs for implementation errors will be prefixed with ':rotating_light:Urban Airship Implementation Error:rotating_light:' in
debug mode. The emoji can be removed by disabling loud implementation errors before takeOff by calling:

```obj-c
    [UAirship setLoudImpErrorLogging:NO];
```

## Building libUAirship from Source

[Source can be found here.](https://github.com/urbanairship/ios-library)

- Update `scripts/configure_xcode_version.sh` with the path to the app bundle for the version of Xcode (e.g. /Applications/Xcode7-beta4.app) that you want to build with.
 Run the distribution script `./scripts/build_distribution.sh`

This will produce a static library (.a file) in the Airship folder as well as the sample projects and Airship library distribution zip file in
Deploy/output

## Testing

The unit tests in this project require OCMock. OCMock can be installed automatically
with the use of our install script, scripts/mock_setup.sh.


## Third Party Packages

### Core Library

Third party Package | License   | Copyright / Creator
------------------- | --------- | -----------------------------------
Base64              | BSD       | Copyright 2009-2010 Matt Gallagher.

### Test Code

Third party Package | License   | Copyright / Creator
------------------- | --------- | -----------------------------------
JRSwizzle           | MIT       | Copyright 2012 Jonathan Rentzsch


## Contributing Code

We accept pull requests! If you would like to submit a pull request, please fill out and submit a
Code Contribution Agreement (http://docs.urbanairship.com/contribution-agreement.html).
