## TestShip Sample Quickstart

### Please Note:

TestShip is an internal application built for functional tests. If you are looking
for a sample application please see the following:
* [iOS Swift Sample](https://github.com/urbanairship/ios-library-dev/tree/master/SwiftSample)
* [iOS Obj-C Sample](https://github.com/urbanairship/ios-library-dev/tree/master/Sample)
* [tvOS Swift Sample](https://github.com/urbanairship/ios-library-dev/tree/master/tvOSSample)

### Getting Started:

1. Run `pod install` in the ios-library-dev root directory to install the project
requirements and generate the `Airship.xcworkspace`.
2. Open the `Airship.xcworkspace`
3. Add an `AirshipConfig.plist` file and add the credentials for the `TestShip`
application (com.urbanairship.testship) and a dictionary under the `customConfig` key.
In the `customConfig` dictionary add the master secret under the `masterSecret` key.
4. Select the `TestShipTests` target on a device and run the tests (⌘-u).
