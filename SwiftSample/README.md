## Swift Sample Quickstart

1. Navigate to `ios-library/SwiftSample` and remove the `.sample` file extension from the `AirshipConfig.plist.sample` file.
2. Open the `AirshipConfig.plist` file and add your development appkey under `developmentAppKey` and your development appsecret under `developmentAppSecret`. If you have production credentials, place your production appkey under `productionAppKey` and your production appsecret under `productionAppSecret`
3. Open `Airship.xcworkspace`, navigate to the SwiftSample project and update the bundle identifier of the SwiftSample project to match the bundle identifier of your provisioned application.
4. Run the SwiftSample target and enable push using the `Enable Push` button on the home screen, or the `Push Enabled` switch on the settings screen.
