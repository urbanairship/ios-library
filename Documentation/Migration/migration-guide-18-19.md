# Airship iOS SDK 18.x to 19.0 Migration Guide

The Airship SDK 19.0 introduces significant updates to improve Swift API support and adopts Swift 6. Major changes include transitioning Objective-C support to a separate framework, converting many classes to structs, and making most public APIs `Sendable`. This guide outlines the major updates and non-obvious changes for migrating from SDK 18.x to SDK 19.0.

---

## Xcode requirements

SDK 19.0 requires **Xcode 16.2 or newer**.

---

## Objective-C Support

Objective-C support has been removed from the core Airship frameworks to leverage Swift APIs fully. A new framework, `AirshipObjectiveC`, provides bindings for apps still using Objective-C. For this first release only the most common APIs will have bindings.

- **Missing Bindings?** Open a GitHub issue to request additional bindings
- Rewrite parts of your application in Swift
- Provide your own Objective-C bindings

---

## Airship Config

The `AirshipConfig` class has been converted to a struct. Key updates include:

1. **Property Changes**:

   - Properties like `appKey` and `appSecret` are now determined during `takeOff` based on the `inProduction` flag.
   - `inProduction` is now an optional Bool. If set the value will be used. If not, it will be inferred by inspecting the APNS environment.

2. **API Updates**:
   - APIs that could fail now throw errors instead of silently failing

| SDK 18.x AirshipConfig API                                  | SDK 19.x AirshipConfig API                                  |
| ----------------------------------------------------------- | ----------------------------------------------------------- |
| class func AirshipConfig.default() -> AirshipConfig         | static func AirshipConfig.default() throws -> AirshipConfig |
| class func AirshipConfig.config() -> AirshipConfig          | init()                                                      |
| class func config(contentsOfFile: String?) -> AirshipConfig | init(fromPlist: String) throws                              |
| init(contentsOfFile: String?) -> AirshipConfig              | init(fromPlist: String) throws                              |
| init(contentsOfFile: String?) -> AirshipConfig              | init(fromPlist: String) throws                              |
| var inProduction: Bool { get set }                          | var inProduction: Bool? { get set }                         |
| var detectProvisioningMode: Bool { get set }                | _REMOVED_                                                   |
| var appKey: String { get }                                  | _REMOVED: determined during takeOff based on inProduction_  |
| var appSecret: String { get }                               | _REMOVED: determined during takeOff based on inProduction_  |
| var logLevel: AirshipLogLevel { get }                       | _REMOVED: determined during takeOff based on inProduction_  |
| var logPrivacyLevel: AirshipLogPrivacyLevel { get }         | _REMOVED: determined during takeOff based on inProduction_  |
| func validate() -> Bool                                     | func validateCredentials(inProduction: Bool) throws         |
| func validate(logIssues: Bool) -> Bool                      | func validateCredentials(inProduction: Bool) throws         |

---

## Changes to `Airship.takeOff`

The `takeOff` methods now throw errors for better error handling. `takeOff` will throw in the following conditions:

- `takeOff` already successfully called.
- `takeOff` was called without an `AirshipConfig` instance and it fails to parse `AirshipConfig.plist`
- `takeOff` was called without an `AirshipConfig` instance and the parsed `AirshipConfig.plist` is invalid (missing credentials)
- `takeOff` was called with an `AirshipConfig` instance with invalid config (missing credentials)

No error will be thrown if the config is properly setup and Airship is only called once during `application(_:didFinishLaunchingWithOptions:)`.

Example error handling:

**Crash on Startup**:

```swift
let config = try! AirshipConfig.default()
try! Airship.takeOff(config, launchOptions: launchOptions)
```

**Log Misconfiguration (SDK 18.x behavior)**:

```swift
do {
    let config = try AirshipConfig.default()
    try Airship.takeOff(config, launchOptions: launchOptions)
} catch {
    print("Airship.takeOff failed: \(error)")
}
```

The absence of an error does not guarantee that the provided app credentials are valid. Airship only verifies that the credentials exist for the specified production mode and conform to the expected length and character set. For new integrations, review the logs for any warnings or errors to ensure a proper setup.

---

## Logging

Logger configuration before `takeOff` is no longer needed. All logging config has moved to `AirshipConfig`.

Example:

```swift
var config = AirshipConfig()

// Log everything publicly to the console for development
config.developmentLogLevel = .verbose
config.developmentLogPrivacyLevel = .public

// Custom log handler
config.logHandler = MyCustomLogHandler()
```

---

## Module component accessors

Accessors for module components have been standardized:

| SDK 18.x Accessors        | SDK 19.x Accessors         |
| ------------------------- | -------------------------- |
| MessageCenter.shared      | Airship.messageCenter      |
| PreferenceCenter.shared   | Airship.preferenceCenter   |
| FeatureFlagManager.shared | Airship.featureFlagManager |
| InAppAutomation.shared    | Airship.inAppAutomation    |

---

## Push options

`UANotificationOptions` and `UAAuthorizationStatus` have been removed. Use Apple's equivalents instead:

| SDK 18.x Type         | SDK 19.x Replacement  |
| --------------------- | --------------------- |
| UANotificationOptions | UNNotificationOptions |
| UAAuthorizationStatus | UNAuthorizationStatus |

`UAAuthorizedNotificationSettings` has been ported to Swift and is now named `AirshipAuthorizedNotificationSettings`:

| SDK 18.x Type                    | SDK 19.x Replacement                  |
| -------------------------------- | ------------------------------------- |
| UAAuthorizedNotificationSettings | AirshipAuthorizedNotificationSettings |

---

## Changes to `PushNotificationDelegate`

The `PushNotificationDelegate` methods are now asynchronous. Update your implementations to match the new async methods.

---

## Changes to `AppIntegration`

For apps disabling automatic integration, methods in `AppIntegration` are now async and decorated with `@MainActor`. Update your implementation to use the async equivalent methods:

```swift
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AppIntegration.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppIntegration.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        return await AppIntegration.application(application, didReceiveRemoteNotification: userInfo)
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await AppIntegration.userNotificationCenter(center, didReceive: response)
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return await AppIntegration.userNotificationCenter(center, willPresent: notification)
    }
```

If you are running into sendable issues with any of the above methods, you should decorate the AppDelegate class with `@MainActor`.

---

## Changes to `AirshipJSON`

`AirshipJSON.wrap` will no longer special case a `Date` by formatting it as an ISO date string. Instead it will use the date formatting strategy defined in the encoder/decoder. `Airship.defaultEncoder` and
`Airship.defaultDecoder` now use the `.iso8601` date strategy. If you are using `Airship.defaultEncoder` or `Airship.defaultDecoder`, you may want to use a default instance instead.

---

## Changes to `CustomEvent`

Custom event property is now a `Decimal` instead of an `NSNumber`. The init methods for the value now only accepts `Double` and `Decimal`. String values are no longer accepted in the init methods so the app
can detect parse failures instead of it silently failing. The property `eventValue` is no longer optional and defaults to 1.0. The default value did not change, just the interface.

Property values are now able to be set with mutating functions on the custom event. These functions will wrap the value as an `AirshipJSON` to make the event `Sendable`. The `JSONEncoder` can now be specified in the function,
the static mutable property `CustomEvent.defaultEncoder` has been replaced by a factory method `CustomEvent.defaultEncoder()` that provides the default encoder for the property mutators if one is not provided.

**API Changes**

| SDK 18.x CustomEvent API                                        | SDK 19.x CustomEvent API                                                       |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| var eventValue: NSNumber? { get set }                           | var eventValue: Decimal { get set }                                            |
| var properties: [String: Any] { get set }                       | var properties: [String: AirshipJSON] { get }                                  |
| var properties: [String: Any] { get set }                       | var properties: [String: AirshipJSON] { get }                                  |
| init(name: String, value: NSNumber?)                            | init(name: String, value: Double) or init(name: String, decimalValue: Decimal) |
| init(name: String, stringValue: String?)                        | _REMOVED: parse the value as a Double first_                                   |
| class func event(name: String) -> CustomEvent                   | init(name: String)                                                             |
| class func event(name: String, string: String?) -> CustomEvent  | _REMOVED: parse the value as a Double first, then use init(name:value:)_       |
| class func event(name: String, value: NSNumber?) -> CustomEvent | init(name: String, value: Double) or init(name: String, decimalValue: Decimal) |

**Property Mutators**

| SDK 19.x Custom Event property functions                                               | Description                                                    |
| -------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| mutating func setProperty(string: String, forKey: String)                              | Sets a string value in the property map                        |
| mutating func setProperty(bool: Bool, forKey: String)                                  | Sets a bool value in the property map                          |
| mutating func setProperty(double: Double, forKey: String)                              | Sets a double value in the property map                        |
| mutating func setProperty(value: Any?, forKey: String, encoder: JSONEncoder) -> throws | Sets a value (wrapped by AirshipJSON) in the property map      |
| mutating func removeProperty(forKey: String)                                           | Removes a property in the property map                         |
| mutating func setProperties(object: Any?, encoder: JSONEncoder) -> throws              | Sets the properties object. The value must result in an object |

---

## Custom Event Templates

The custom event templates classes have been removed and replaced with new `CustomEvent` init methods.

| SDK 18.x template class | SDK 19.x replacement                          |
| ----------------------- | --------------------------------------------- |
| AccountEventTemplate    | CustomEvent.init(accountTemplate:properties:) |
| RetailEventTemplate     | CustomEvent.init(retailTemplate:properties:)  |
| SearchEventTemplate     | CustomEvent.init(searchTemplate:properties:)  |
| MediaEventTemplate      | CustomEvent.init(mediaTemplate:properties:)   |

The LTV (life time value) property use to be set if the template defined a value. This would lead to inconsistent results depending on if the value was set on the template vs
setting the value on the generated custom event. The SDK will no longer automatically set the `ltv` property, it now can be set in the template properties:

```
    var event = CustomEvent(
        searchTemplate: .search,
        properties: CustomEvent.SearchProperties(
            isLTV: true
        )
    )
    event.eventValue = 100.0
```
