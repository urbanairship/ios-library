# Airship iOS SDK 19.x to 20.0 Migration Guide

The Airship SDK 20.0 introduces major architectural changes including UI refactors for Message Center and Preference Center, a protocol-first architecture for core components, and modern block-based callback alternatives to delegate patterns. The minimum deployment target is raised to iOS 16+. This guide outlines the necessary changes for migrating your app from SDK 19.x to SDK 20.0.

---

## SDK 20 requirements

- **Xcode 26 or newer**
- iOS 16+
- tvOS 18+
- visionOS 1+

---

## Preference Center Refactor

The Preference Center has been refactored to provide a clearer separation between content and navigation, and to simplify customization.

### View Hierarchy Changes

The main view `PreferenceCenterView` is now a wrapper that provides a `NavigationStack`. The core content, previously known as `PreferenceCenterList`, has been renamed to `PreferenceCenterContent`.

- `PreferenceCenterView`: Use this view for a standard Preference Center implementation with navigation.
- `PreferenceCenterContent`: Use this view if you want to provide your own navigation or embed the Preference Center within another view.

### API Updates

Several types and protocols have been renamed for clarity:

| SDK 19.x API | SDK 20.x API |
| --- | --- |
| `PreferenceCenterList` | `PreferenceCenterContent` |
| `PreferenceCenterViewPhase` | `PreferenceCenterContentPhase` |
| `PreferenceCenterViewLoader` | `PreferenceCenterContentLoader` |
| `PreferenceCenterViewStyle` | `PreferenceCenterContentStyle` |
| `PreferenceCenterViewStyleConfiguration` | `PreferenceCenterContentStyleConfiguration` |


### Navigation Changes

The `PreferenceCenterNavigationStack` enum and the `preferenceCenterNavigationStack()` view modifier have been removed. `PreferenceCenterView` now always uses a `NavigationStack`. If you were previously using `.none`, you should switch to using `PreferenceCenterContent` directly.

**Before (SDK 19.x):**
```swift
// To provide custom navigation
PreferenceCenterView(preferenceCenterID: "your_id")
    .preferenceCenterNavigationStack(.none)
```

**After (SDK 20.x):**
```swift
// Use PreferenceCenterContent directly
PreferenceCenterContent(preferenceCenterID: "your_id")
```

---

## Message Center Refactor

The Message Center UI has been refactored for greater flexibility and clearer API boundaries, separating navigation from content.

### View Hierarchy Changes

The top-level `MessageCenterView` is now a navigation container. The actual content is rendered by `MessageCenterContent`.

- `MessageCenterView`: Use this view for a standard Message Center implementation. It provides either a `NavigationStack` or a `NavigationSplitView`, which can be controlled via the new `navigationStyle` parameter.
- `MessageCenterContent`: Use this view if you need to provide your own navigation or embed the Message Center within a custom view hierarchy.

### API Updates

| SDK 19.x API | SDK 20.x API |
| --- | --- |
| `MessageCenterViewStyle` | `MessageCenterContentStyle` |
| `messageCenterViewStyle()` | `messageCenterContentStyle()` |
| `MessageCenterStyleConfiguration` | `MessageCenterContentStyleConfiguration` |

### Navigation Changes

The `MessageCenterNavigationStack` enum and the `messageCenterNavigationStack()` view modifier have been removed. Navigation is now controlled by the `navigationStyle` parameter on `MessageCenterView`.

**Before (SDK 19.x):**
```swift
// Basic Message Center
MessageCenterView()

// With custom navigation
MessageCenterView()
    .messageCenterNavigationStack(.none)
```

**After (SDK 20.x):**
```swift
// Stack-based navigation (default on iPhone)
MessageCenterView(navigationStyle: .stack)

// Split-view navigation (default on iPad)
MessageCenterView(navigationStyle: .split)

// To provide custom navigation, use MessageCenterContent
MessageCenterContent()
```

---

## UI Architecture Changes

Both the Message Center and Preference Center now follow a "Container vs. Content" architecture. This pattern separates the views responsible for navigation from the views responsible for displaying content.

### Preference Center

-   **`PreferenceCenterView`**: This is the container view. It sets up the `NavigationStack` and is responsible for the navigation bar's title and back button.
-   **`PreferenceCenterContent`**: This is the content view. It loads and displays the list of preferences. Use this directly if you want to provide your own navigation.

### Message Center

The Message Center UI is broken down into several public components that can be used to build a custom experience:

-   **`MessageCenterView`**: The top-level container that provides a `NavigationStack` or `NavigationSplitView`.
-   **`MessageCenterContent`**: The core content view that coordinates the message list. Use this view if you need to provide your own navigation.
-   **`MessageCenterListViewWithNavigation`**: This view displays the list of messages and **is responsible for the navigation bar content**, including the title and the edit/toolbar buttons.
-   **`MessageCenterListView`**: A simpler view that only displays the list of messages, without any navigation bar items.
-   **`MessageCenterMessageViewWithNavigation`**: Displays a single message and manages its navigation bar.
-   **`MessageCenterMessageView`**: Displays a single message without a navigation bar.
---

## Protocol-First Architecture

SDK 20.0 refactors core Airship components to use protocols instead of concrete classes. The existing functionality remains the same, but the implementation is now hidden behind protocol interfaces. This change provides better testability, modularity, and allows for easier customization and mocking.

### Class-to-Protocol Conversions

Several core Airship classes have been converted to protocols (with the same functionality):

| SDK 19.x Class | SDK 20.x Protocol |
| --- | --- |
| `AirshipPrivacyManager` | `AirshipPrivacyManager` |
| `AirshipPermissionsManager` | `AirshipPermissionsManager` |
| `MessageCenter` | `MessageCenter` |
| `InAppAutomation` | `InAppAutomation` |
| `PreferenceCenter` | `PreferenceCenter` |
| `InAppMessaging` | `InAppMessaging` |
| `LegacyInAppMessaging` | `LegacyInAppMessaging` |
| `AirshipActionRegistry` | `AirshipActionRegistry`  |
| `AirshipChannelCapture` | `AirshipChannelCapture` |
| `FeatureFlagManager` | `FeatureFlagManager` |

### Protocol Renames

Several protocols have been renamed to remove the "Protocol" suffix:

| SDK 19.x Protocol | SDK 20.x Protocol |
| --- | --- |
| `AirshipAnalyticsProtocol` | `AirshipAnalytics` |
| `AirshipChannelProtocol` | `AirshipChannel` |
| `AirshipContactProtocol` | `AirshipContact` |
| `AirshipPushProtocol` | `AirshipPush` |
| `PrivacyManagerProtocol` | `AirshipPrivacyManager` |
| `URLAllowListProtocol` | `AirshipURLAllowList` |
| `AirshipLocaleManagerProtocol` | `AirshipLocaleManager` |
| `InAppMessagingProtocol` | `InAppMessaging` |
| `LegacyInAppMessagingProtocol` | `LegacyInAppMessaging` |

### Migration Impact

**For most developers:** These changes are primarily internal and won't affect your code. The public APIs remain the same - you can continue using `Airship.contact`, `Airship.privacyManager`, `Airship.messageCenter`, `Airship.inAppAutomation`, `Airship.preferenceCenter`, etc. as before.

---

## Deprecated APIs

Several APIs have been deprecated in SDK 20.0 and will be removed in future versions. Update your code to use the recommended alternatives.

### Attribute Management

**Before (SDK 19.x):**
```swift
// Old method using Int
Airship.contact.editAttributes { editor in
    editor.set(number: 42, attribute: "age")
}
Airship.channel.editAttributes { editor in
    editor.set(number: 100, attribute: "score")
}
```

**After (SDK 20.x):**
```swift
// New method using Double
Airship.contact.editAttributes { editor in
    editor.set(number: 42.0, attribute: "age")
}
Airship.channel.editAttributes { editor in
    editor.set(number: 100.0, attribute: "score")
}
```

### Preference Center Display

**Before (SDK 19.x):**
```swift
// Old method
Airship.preferenceCenter.openPreferenceCenter(preferenceCenterID: "my_id")
```

**After (SDK 20.x):**
```swift
// New method
Airship.preferenceCenter.display("my_id")
```

---

## Block-Based Callback Alternatives

To provide a more modern and convenient Swift API, SDK 20 introduces block-based (closure) callbacks as an alternative to several common delegate protocols. These new callbacks improve code locality and can reduce boilerplate for simple event handling.

The delegate-based approach is still fully supported, but we recommend adopting the new block-based callbacks for new implementations. **The delegate patterns will be deprecated in a future 20.x release and removed in SDK 21.0.0**

All new callback closures are `@MainActor` and `@Sendable` to ensure thread safety and simplify UI updates.

### Push Notifications

Instead of conforming to `PushNotificationDelegate`, you can now set individual closures on `Airship.push`. If a block is provided for a specific event, the corresponding `PushNotificationDelegate` method will be ignored.

**Before:**
```swift
// A class that implements the delegate
class MyPushDelegate: PushNotificationDelegate {
    func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        // Handle response asynchronously
        await someAsyncTask()
    }
    // ... other delegate methods
}

// In your app, store a strong reference to the delegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let pushDelegate = MyPushDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ...
        
        // After takeOff
        Airship.push.pushNotificationDelegate = pushDelegate
        return true
    }
}
```

**After:**
```swift
// In your app's startup code
Airship.push.onReceivedNotificationResponse = { response in
    // Handle response asynchronously
    await someAsyncTask()
}
```

**New APIs on `Airship.push`:**
- `onReceivedForegroundNotification`
- `onReceivedBackgroundNotification`
- `onReceivedNotificationResponse`
- `onExtendPresentationOptions`

### Registration

The `RegistrationDelegate` has also been broken down into more granular, event-specific closures. If a block is provided, it will be used instead of the corresponding delegate method.

**Before:**
```swift
// A class that implements the delegate
class MyRegistrationDelegate: RegistrationDelegate {
    func apnsRegistrationSucceeded(withDeviceToken deviceToken: Data) {
        print("APNs registration succeeded")
    }

    func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings: AirshipAuthorizedNotificationSettings,
        status: UNAuthorizationStatus
    ) {
        print("Notification registration finished with status: \(status)")
    }
}

// In your app, store a strong reference to the delegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let registrationDelegate = MyRegistrationDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ...
        
        // After takeOff
        Airship.push.registrationDelegate = registrationDelegate
        return true
    }
}
```

**After:**
```swift
// In your app's startup code

// Handle APNS registration updates
Airship.push.onAPNSRegistrationFinished = { result in
    switch result {
    case .success(let deviceToken):
        print("APNs registration succeeded: \(deviceToken)")
    case .failure(let error):
        print("APNs registration failed: \(error)")
    }
}

// Handle user notification registration updates
Airship.push.onNotificationRegistrationFinished = { result in
    print("Notification registration finished with status: \(result.status)")
}

// Handle changes to authorized notification settings
Airship.push.onNotificationAuthorizedSettingsDidChange = { settings in
    print("Authorized settings changed: \(settings)")
}
```

**New APIs on `Airship.push`:**
- `onAPNSRegistrationFinished` with `APNSRegistrationResult`
- `onNotificationRegistrationFinished` with `NotificationRegistrationResult`
- `onNotificationAuthorizedSettingsDidChange`

The new callbacks use the following data structures:

```swift
/// The result of an APNs registration.
public enum APNSRegistrationResult: Sendable {
    /// Registration was successful and a new device token was received.
    case success(deviceToken: String)

    /// Registration failed.
    case failure(error: any Error)
}

/// The result of the initial notification registration prompt.
public struct NotificationRegistrationResult: Sendable {
    /// The settings that were authorized at the time of registration.
    public let authorizedSettings: AirshipAuthorizedNotificationSettings

    /// The authorization status.
    public let status: UNAuthorizationStatus

    #if !os(tvOS)
    /// Set of the categories that were most recently registered.
    public let categories: Set<UNNotificationCategory>
    #endif
}
```

### Deep Links

Instead of conforming to `DeepLinkDelegate`, you can now set a closures on `Airship`. If the `onDeepLink` block is set, the `DeepLinkDelegate` will be ignored.

**Before:**
```swift
class MyDeepLinkDelegate: DeepLinkDelegate {
    func receivedDeepLink(_ deepLink: URL) async {
        // Handle deep link asynchronously
        await someNavigationTask(url)
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    private let deepLinkDelegate = MyDeepLinkDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ...
        
        // After takeOff
        Airship.deepLinkDelegate = deepLinkDelegate
        return true
    }
}
```

**After:**
```swift
Airship.onDeepLink = { url in
    // Handle deep link asynchronously
    await someNavigationTask(url)
}
```

**New API on `Airship`:**
- `onDeepLink`

### URL Allow List

Instead of conforming to `URLAllowListDelegate`, you can now set the `onAllowURL` closure on `Airship.urlAllowList`. If the `onAllowURL` block is set, the `URLAllowListDelegate` will be ignored.

**Before:**
```swift
class MyURLDelegate: URLAllowListDelegate {
    func allowURL(_ url: URL, scope: URLAllowListScope) -> Bool {
        // Custom URL validation logic
        return url.host?.contains("trusted-domain.com") == true
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    private let urlDelegate = MyURLDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ...
        
        // After takeOff
        Airship.urlAllowList.delegate = urlDelegate
        return true
    }
}
```

**After:**
```swift
Airship.urlAllowList.onAllowURL = { url, scope in
    // Custom URL validation logic
    return url.host?.contains("trusted-domain.com") == true
}
```

**New API on `Airship.urlAllowList`:**
- `onAllowURL`

### Displaying the Message Center

Instead of `MessageCenterDisplayDelegate`, you can now use the `onDisplay` and `onDismissDisplay` closures on `Airship.messageCenter`. The `onDisplay` closure should return `true` if the display was handled, or `false` to let the SDK fall back to its default UI. If the `onDisplay` block is set, the delegate will be ignored.

**Before:**
```swift
class MyDisplayDelegate: MessageCenterDisplayDelegate {
    func displayMessageCenter(messageID: String?) {
        // Display Message Center UI
    }

    func dismissMessageCenter() {
        // Dismiss Message Center UI
    }
}

// Store a strong reference
private let displayDelegate = MyDisplayDelegate()

// In your app's startup code
Airship.messageCenter.displayDelegate = displayDelegate
```

**After:**
```swift
Airship.messageCenter.onDisplay = { messageID in
    // Display custom Message Center UI
    // Return true to prevent the default SDK display behavior.
    return true
}

Airship.messageCenter.onDismissDisplay = {
    // Dismiss Message Center UI
}
```

### Displaying the Preference Center

Instead of `PreferenceCenterOpenDelegate`, you can use the new `onDisplay` closure on `Airship.preferenceCenter`. The closure should return `true` if the display was handled, or `false` to let the SDK fall back to its default UI. If the `onDisplay` block is set, the delegate will be ignored.

**Before:**
```swift
class MyOpenDelegate: PreferenceCenterOpenDelegate {
    func openPreferenceCenter(preferenceCenterID: String) {
        // Display Preference Center UI
    }
}

// Store a strong reference
private let openDelegate = MyOpenDelegate()

// In your app's startup code
Airship.preferenceCenter.openDelegate = openDelegate
```

**After:**
```swift
Airship.preferenceCenter.onDisplay = { preferenceCenterID in
    // Display custom Preference Center UI
    // Return true to prevent the default SDK display behavior.
    return true
}
```