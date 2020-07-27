## Sample Quickstart

1. Navigate to `ios-library/Sample` and remove the `.sample` file extension from the `AirshipConfig.plist.sample` file.
2. Open the `AirshipConfig.plist` file and add your development appkey under `developmentAppKey` and your development appsecret under `developmentAppSecret`. If you have production credentials, place your production appkey under `productionAppKey` and your production appsecret under `productionAppSecret`.
3. Open `Sample.xcodeproj` and update the bundle identifier of the Sample project to match the bundle identifier of your provisioned application.
4. Run the Sample target and enable push using the `Enable Push` button on the home screen, or the `Push Enabled` switch on the settings screen.

### Please Note:
* Push notifications will not function in the simulator.
* Setup instructions for Cocoapods and Carthage are available in the [ios-library README](https://github.com/urbanairship/ios-library/blob/main/README.md).
* Bundle identifiers added to the sample must correspond to a provisioned application in the [Apple developer portal](https://developer.apple.com/) and have a valid [Universal push certificate](https://developer.apple.com/library/content/documentation/IDEs/Conceptual/AppDistributionGuide/AddingCapabilities/AddingCapabilities.html).
