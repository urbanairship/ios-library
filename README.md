# Airship iOS SDK

The Airship SDK for iOS provides a simple way to integrate Airship
services into your iOS applications.

## Resources

- [AirshipCore Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipCore)
- [AirshipBasement Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipBasement/)
- [AirshipAccengage Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipAccengage)
- [AirshipAutomation Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipAutomation)
- [AirshipChat Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipChat)
- [AirshipExtendedActions Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipExtendedActions)
- [AirshipLocation Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipLocation)
- [AirshipMessageCenter Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipMessageCenter)
- [AirshipPreferenceCenter Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipPreferenceCenter)
- [AirshipNotificationServiceExtension Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipNotificationServiceExtension)
- [AirshipNotificationContentExtension Docs](https://docs.airship.com/reference/libraries/ios/latest/AirshipNotificationContentExtension)

- [Getting started guide](http://docs.airship.com/platform/ios/)
- [Migration Guides](Documentation/Migration/README.md)
- [Sample Quickstart Guide](Sample/README.md)
- [Swift Sample Quickstart Guide](SwiftSample/README.md)

## Installation

Xcode 13.0+ is required to use the Airship SDK.

### CocoaPods

Make sure you have the [CocoaPods](http://cocoapods.org) dependency manager installed. You can do so by executing the following command:

```sh
$ gem install cocoapods
```

The primary Airship pod includes the standard feature set and is advisable to use
for most use cases. The standard feature set includes Push, Actions,
In-App Automation, and Message Center

Example podfile:

```txt
# Airship SDK
target "<Your Target Name>" do
  pod 'Airship'
end
```

The `Airship` pod also contains several subspecs that can be installed
independently and in combination with one another when only a particular
selection of functionality is desired:

- `Airship/Core` : Push messaging features including channels, tags, named user and default actions
- `Airship/MessageCenter` : Message center
- `Airship/Automation` : Automation and in-app messaging
- `Airship/Location` : Location including geofencing and beacons
- `Airship/ExtendedActions` : Extended actions
- `Airship/PreferenceCenter` : Preference center
- `Airship/Chat` : Live chat

Example podfile:

```txt
target "<Your Target Name>" do
  pod 'Airship/Core'
  pod 'Airship/MessageCenter'
  pod 'Airship/Automation'
end
```

Install using the following command:
```sh
$ pod install
```

In order to take advantage of notification attachments, you will need to create a notification service extension
alongside your main application. Most of the work is already done for you, but since this involves creating a new target there
are a few additional steps. First create a new "Notification Service Extension" target. Then add AirshipExtensions/NotificationService
to the new target:

```txt
# Airship SDK
target "<Your Service Extension Target Name>" do
  pod 'AirshipServiceExtension'
end
```

Install using the following command:

```sh
$ pod install
```

Then delete all the dummy source code for the new extension and have it inherit from UANotificationServiceExtension:

```
import AirshipServiceExtension

class NotificationService: UANotificationServiceExtension {

}
```

### Other Installation Methods

For other installation methods, see the - [Getting started guide](http://docs.airship.com/platform/ios.html#installation).

## Quickstart

### An Important Note about Location

In Spring 2019, Apple began rejecting applications that use, or appear to use, Core Location services
without supplying usage descriptions in their `Info.plist` files. In Airship SDK 11, all references to
CoreLocation have been removed from the core library and placed in a separate location framework. Developers with
no need for location services can continue to use Airship as before, but for those who have been using the
`UALocation` class, see the [Location](https://docs.airship.com/platform/ios/location/) sections for updated
setup instructions.

## Warning

As of SDK 10.2 and Apple's current App Store review policies, apps building against Airship without location usage
descriptions in  `Info.plist` are likely to be rejected. The easiest way to avoid this, if location services are not
needed, is to use Airship SDK 11 or greater. If building against previous Airship SDKs, you will need to add add
usage description strings to your `Info.plist` file under the `NSLocationAlwaysUsageDescription`,
`NSLocationWhenInUseUsageDescription`, and `NSLocationAlwaysAndWhenInUseUsageDescription` keys.

### Capabilities

Enable Push Notifications and Remote Notifications Background mode under the capabilities section for
the main application target.

### Adding an Airship Config File

The library uses a .plist configuration file named `AirshipConfig.plist` to manage your production and development
application profiles. Example copies of this file are available in all of the sample projects. Place this file
in your project and set the following values to the ones in your application at http://go.urbanairship.com.  To
view all the possible keys and values, see the [Config class reference](https://docs.airship.com/reference/libraries/ios/latest/AirshipCore/Classes/Config.html)

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

### Call Takeoff

To enable push notifications, you will need to make several additions to your application delegate.

```
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    ...

    Airship.takeOff(launchOptions: launchOptions)

    return true
}
```

To enable push later on in your application:

```
    // Somewhere in the app, this will enable push (setting it to NO will disable push,
    // which will trigger the proper registration or de-registration code in the library).
    Airship.push.userPushNotificationsEnabled = true
```

## SDK Development

Make sure you have the CocoaPods dependency manager installed. You can do so by executing the following command:

```sh
$ gem install cocoapods
```

Install the pods:

```sh
$ pod install
```

Open Airship.xcworkspace

```sh
$ open Airship.xcworkspace
```

Update the Samples AirshipConfig by copying`AirshipConfig.plist.sample` to `AirshipConfig.plist` and update
the app's credentials. You should now be able to build, run tests, and run the samples.

The distribution can be generated by running the build.sh script:

```sh
./scripts/build.sh
```

Continuous integration will run `scripts/run_ci_tasks.sh` for every PR submitted.
