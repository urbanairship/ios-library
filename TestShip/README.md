## TestShip Quickstart

### Please Note:

TestShip is an internal application built for functional tests. If you are looking
for a sample application please see the following:
* [iOS Swift Sample](../SwiftSample)
* [iOS Obj-C Sample](../Sample)
* [tvOS Swift Sample](../tvOSSample)

### Getting Started:

1. Run `pod install` in the ios-library-dev root directory to install project
requirements and generate `Airship.xcworkspace`.
2. Open `Airship.xcworkspace`.
3. Add an `AirshipConfig.plist` file and add the credentials for the `TestShip`.
application (com.urbanairship.testship) and a dictionary under the `customConfig` key.
In the `customConfig` dictionary add the master secret under the `masterSecret` key.
4. Select the `TestShipTests` target on a device and run tests (⌘-u).
