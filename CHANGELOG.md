
# iOS Changelog

## Version 18.5.0 July 1, 2024
Minor release that includes cert pinning and various fixes and improvements for Preference Center, In-app Messages and Embedded Content.

### Changes
- Added ability to inject a custom certificate verification closure that applies to all API calls
- Added width and height parameters to in-app dismiss button theming
- Fixed bug that caused HTML in-app message backgrounds to default to clear instead of system background
- Fixed extra payload parsing in in-app messages
- Set default banner placement to bottom
- Increased impression interval for embedded in-app views
- Improved in-app banner view accessibility
- Preference center contact channel listing is now refreshed on foreground and from background pushes

## Version 18.4.1 June 21, 2024
Patch release to fix a regression with IAX ignoring screen, version, and custom event triggers. Apps using those triggers that are on 18.4.0 should update.

### Changes
- Fixed trigger regression for IAX introduced in 18.4.0.

## Version 18.4.0, June 14, 2024
Minor release that adds contact management support to the preference center, support for anonymous channels, per-message in-app message theming, message center customization and logging improvements. Apps that use the message center or stories should update to this version.

### Changes
- Added support for anonymous channels
- Added contact management support in preference centers
- Added improved theme support and per message theming for in-app messages
- Added public logging functions
- Fixed bug in stories page indicator
- Fixed message center list view background theming

## Version 18.3.1, May 27, 2024
Patch release with bug fix for message center customization. Apps that use the message center should update to this version.

### Changes
- Fixed background color application in message center.

## Version 18.3.0, May 20, 2024
Minor release with updates to message center customization, a bug fix for story pager transition animation and a bug fix for in-app banner button rendering.

### Changes
- Fixed in-app message banner button rendering.
- Fixed story pager transition animation.
- Added message center list and list container background color customization via new plist keys `messageListBackgroundColor`, `messageListBackgroundColorDark`, `messageListContainerBackgroundColor` and `messageListContainerBackgroundColorDark`

## Version 18.2.2, May 15, 2024
Patch release includes a fix for submission issues when building with XCFrameworks, a bug fix for emitting pager events from in-app pager views, and a bug fix for the in-app banner's default title and body alignment to match the dashboard preview. Apps using XCFrameworks should update.

### Changes
- Fixed pager event emission from in-app pager views.
- Fixed submission issue when building with XCFrameworks.
- Fixed in-app banner title and body default alignment.

## Version 18.2.1, May 14, 2024
Patch release that makes IAA name property is optional and defaults to an empty string.

### Changes
- Fixed InAppMessage parsing to handle the optional name property.
- Ignore invalid schedules on parsing.

## Version 18.2.0, May 7, 2024
Minor release with updates for in-app message customization, video playback improvements in scenes, web view inspection configuration and several bug fixes. Apps that require obj-c support or are migrating from an older version of the SDK to 18.x should update to this version.

### Changes
- Added in-app message tap opacity and shadow customization via new plist keys `tapOpacity` and `shadowTheme`.
- Added isWebViewInspectionEnabled key to AirshipConfig that allows enabling or disabling web view inspection on Airship created web views. Applied only to iOS 16.4+.
- Added improvements for video playback in scenes.
- Fixed CoreData migration errors from SDK 16 and SDK 17 to SDK 18.
- Fixed in-app message banner display issues within navigation controllers.
- Exposed push singelton to Objective-C
- Exposed UAnotificationServiceExtension to Objective-C.

## Version 18.1.2, April 29, 2024
Patch release with a bug fix for data migration. Apps migrating from an older version of the SDK to 18.x using cocoapods should update to this version.

### Changes
- Exposes mapping classes UARemoteDataMapping and UAInboxDataMapping to obj-c and removes module-specific prefixes from mapping files.

## Version 18.1.1, April 23, 2024
Patch release with a bug fix for contact operations.

### Changes
- Fixed a typo in the dutch translation of the notification action button "Vertel Mij Meer".
- Fixed obj-c bindings not being public.

## Version 17.10.1, April 23, 2024
Patch release with a bug fix for contact operations.

### Changes
- Fixed a typo in the dutch translation of the notification action button "Vertel Mij Meer".

## Version 18.1.0 April 16, 2024

Minor release with several minor API additions.

### Changes
- `MessageCenterInboxProtocol` changes:
  - Added new method `refreshMessages(timeout:)` that will throw if a timeout is reached.
  - Updated the method `refreshMessages()` to properly cancel if the task is cancelled.
  - Refreshing messages will no longer block on network connection availability.
- Added property `identifierUpdates` on `AirshipChannelProtocol` that provides a stream of updates whenever the channel ID changes.
- Added new `AirshipConfig` properties:
  - `resetEnabledFeatures` to reset the `PrivacyManager` enabled features to those specified in config on init.
  - `restoreMessageCenterOnReinstall` to control Message Center recovery on reinstall.
- Added `quietTime` property on `AirshipPushProtocol` to be able to get/set quiet time start and end time.
- Custom event properties will now accept any `Encodable` values and be automatically encoded to JSON.
- Added support for attributing a custom event to an in-app message if the event was generated from the message.
- Updated the LICENSE file to use the standard Apache 2.0 text to be properly detected by Github. The license did not change, only the text describing the license.
- Fixed `Package.swift` to properly support `VisionOS` platform.
- Fixed in-app messages that were interrupted during display that define a display interval not able to be triggered for display again until the next app init.

## Version 16.12.7, April 11, 2024
Patch release that adds a privacy manifest

### Changes
- Adds privacy manifest.

## Version 17.10.0, April 4, 2024
Minor release with a new config option `resetEnabledFeatures` to reset the PrivacyManager enabled features to those specified in the Airship config on each launch and a bug fix for the delete button theming in the Message Center and back button theming in message views.

### Changes
- Added `resetEnabledFeatures` config option
- Fixes color theme assignment for the delete button in Message Center and back button in message views.


## Version 18.0.1 March 22, 2024

Patch release that fixes a few regressions with 18.0.0.

### Changes
- Fixed issue with frequency checks being checked before the message is ready to display
- Fixed an issue with InApp potentially being blocked when upgrading from the prerelease version of 18.0.0 to the final version of 18.0.0


## Version 18.0.0 March 21, 2024

Major SDK release with several breaking changes. see the [Migration Guide](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration/migration-guide-17-18.md) for more info.

### Changes
- Xcode 15.2+ is now required
- Added support for starting Live Activities from a push
- Notification Service extension is now rewritten in Swift
- New Swift Automation module
  - Objective-c support has been removed
  - Breaking API changes for any apps using custom display adapters
  - Added concurrent automation processing to reduce latency if more than one automation is triggered at the same time
- Badge modification methods are now async and use the updated UserNotification methods
- Consolidated NSNotificationNames and keys to AirshipNotifications class
- Replaced access to AirshipPush, AirshipContact, AirshipChannel, AirshipAnalytics with protocols
- Updated Airship accessors to all be class vars instead of a mix of class and instance vars
- Preliminary VisionOS support when using XCFrameworks or SPM
- Added window animations for Scene & Survey transitions
- Fixed Core Data warnings with Xcode 15
- Fixed various sendable warnings when using targeted concurrency checking

## Version 17.9.1, March 20, 2024
Patch release with a bug fix for edit button theming in Message Center.

### Changes
- Fixes color theme assignment for the edit button in Message Center.

## Version 17.9.0, March 14, 2024
Minor release with several bug fixes and stability improvements.

### Changes
- Added message center predicate functionality
- Fixed top-placed in-app message corner rounding
- Added message center theming support for named colors and dark mode
- Exposed additional preference center constructors to enable styling

## Version 18.0.0-rc March 6, 2024

RC release for 18.0.0.

### Changes
- Fixed 18.0.0-beta regression where IAA would reset its internal state and display again after reaching the display limit
- Fixed 18.0.0-beta regression with malformed IAA resolution events
- Fixed 18.0.0-beta regression where contact operations where ignored
- Notification Service extension is now rewritten in Swift
- Badge modification methods are now async and use the updated UserNotification methods
- Removed visionOS from the podspec for now due to a cocoapod issue with publishing

## Version 17.8.0, March 4, 2024
Minor release with several bug fixes and stability improvements.

### Changes
- Added new AirshipConfig value `useUserPreferredLocale` that if set to true, Airship will use the device preferred locale instead of the app's locale for as a device property.
- Expose the addMessageCenterDismissAction view extension for Message Center UI.
- Fixed regression where Preference Center title in the theme was ignored.
- Fixed an issue with the key chain migrating old Airship values to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- Fixed modifying a coredata entity on the wrong context.

## Version 18.0.0-beta.2 February 22, 2024

Second SDK 18.0.0 beta.

### Changes
- Added support for push to start tokens in live activities. Start tokens will automatically be tracked for attribute types passed into the `restore` call.
- Added migration guide for 17.x -> 18.x.
- Updated Airship accessors to all be class vars instead of a mix of class and instance vars.
- Replaced access to AirshipPush, AirshipContact, AirshipChannel, AirshipAnalytics with protocols.
- Consolidated NSNotificationNames and keys to AirshipNotifications class.
- Fixed sendable warnings in PreferenceCenter and MessageCenter module.
- Fixed Core Data warnings with Xcode 15.

## Version 18.0.0-beta February 9, 2024

First beta release of SDK 18.0.0. This release contains a new automation module that has been rewritten in Swift and preliminary visionOS support.

### Changes
- New Swift Automation module. Objective-c support has been removed for this module and custom display adapters have new APIs.
- VisionOS support
- Xcode 15.2+ is required


## Version 17.7.3 Jan 29, 2024
Patch release that fixes an issue with message limits not being respected in certain cases.

### Changes
- Fixed message limits not being respected in certain cases.

## Version 16.12.6, Jan 29, 2024
Patch release that fixes an issue with message limits not being respected in certain cases. Apps on SDK v16 that make use of limits should update to this version or the latest 17.x release.

### Changes
- Fixed message limits not being respected in certain cases.


## Version 17.7.2 January 24, 2023
Patch release improving SDK stability and a fix for core-data warnings with Xcode 15.

### Changes
- Override hashing for MessageCenterMessage
- Fixed core-data warnings
- Fixed potential crash due to de-duping conflicts events in AirshipContact

## Version 17.7.1 December 18, 2023
Patch release that fixes an issue with app background events being attributed to the wrong session ID. This issue was introduced in 17.5.0 and impacts
session duration times in Performance Analytics. Applications that rely on that report should update.

### Changes
- Fixed background app event session ID

## Version 17.7.0 December 6, 2023
Minor release that adds a new MessageCenter listener for current message state and a new method `Airship.contact.notifyRemoteLogin()` that will refresh the local state on the device for named user associations that occur through the server instead of the SDK.

### Changes
- Added new method `Airship.contact.notifyRemoteLogin()`
- Added `MessageCenterController.statePublisher` to listen for the state of the Message Center
- Fixed Preference Center title
- Fixed direct open tracking regression introduced in 17.6.1
- Fixed direct open tracking when opening a content-available=1 notification from a cold start
- Fixed a possible issue with an IAX session trigger if at start a system prompt is displayed

## Version 17.6.1 November 20, 2023
Patch release that adds debug symbols to the prebuilt xcframeworks and includes fixes for SPM and Message Center.

### Changes
- Fixed SPM packages not building due to a duplicate symbol
- Fixed Message Center list view showing a small image icon if a list icon is available and the theme does not enable list icons
- Added debug symbols to xcframeworks to make stack traces easier to read

## Version 17.6.0 November 9, 2023
Minor release that adds support for server side feature flag segmentation, Impression billing, and improves support for animated webP images in Scenes.

### Changes
- Added server side segmentation for feature flags
- Added support for Animated webP frame duration
- Added support for Impression billing
- Scene images will preload the first frame of each image in a scene to avoid the image animating in on page view
- Fixed swipe voice commands for Scenes

## Version 17.5.1 October 18, 2023
Patch release that fixes an issue with Live Activity registration reporting the wrong value on app restart and fixes a regression introduced in 17.5.0 with image loading in both the Preference Center and Message Center OOTB UI.

### Changes
- Fixed Message Center list icon loading
- Fixed Preference Center alert icon loading
- Fixed Live Activity registration status reporting `registered` before it actually is able to register. This only occurs if the Live Activity was tracked and failed to generate a token before the app is restarted.

## Version 16.12.5, October 18, 2023
Patch release that extends background time for Live Activity token generation from 10 seconds to 30 seconds and forces a Live Activity registration update on background if it previously failed.

### Changes
- Added an additional attempt to upload a Live Activity registration upload on background if it previously failed.
- Extended the background task used for waiting for a Live Activity token from 10 seconds to 30 seconds.
- Prebuilt frameworks now use Xcode 14 instead of Xcode 13 due to App store restrictions

## Version 17.5.0 October 12, 2023
Minor release that adds support for querying the Airship registration status of a Live Activity, improves gif loading in Scenes & Surveys, and improves text input handling in Surveys. Applications that use Live Activities or several large GIFs in Scenes & Surveys should update.

### Changes
- Optimized GIF loading for Scenes & Surveys.
- Improve text input on iOS 16+ for Surveys.
- Fixed carthage build due to a missing dependency on AirshipDebug.
- Added an additional attempt to upload a Live Activity registration upload on background if it previously failed.
- Added new `liveActivityRegistrationStatusUpdates(name:)` and `liveActivityRegistrationStatusUpdates(activity:)` on `AirshipChannel` to make it possible to query the current registration status of a Live Activity with Airship.
- Extended the background task used for waiting for a Live Activity token from 10 seconds to 30 seconds.

## Version 17.4.0 September 28, 2023
Minor release that improves refreshing the feeds for in-app experiences and feature flags, adds a new interaction event for feature flags, and fixes a reporting issue with direct opens and sessions counts for apps that are scene enabled.

### Changes
- Improve refresh handling of remote-data for IAX and feature flags.
- Added new method `trackInteraction(flag:)` for Feature Flags.
- Added new optional parameter `dismissAction` on the `MessageCenterListView` view
- Fixed app session and direct open reporting for scene enabled applications

## Version 17.3.1 September 13, 2023
Patch release that updates the prebuilt XCFrameworks for Xcode 15 to use the new Xcode 15 RC release. 

### Changes
- Update the Xcode 15 prebuilt XCFrameworks to use Xcode 15 RC release.

## Version 17.3.0 September 7, 2023
Minor release that adds a privacy manifest that declares the default data collected by the Airship SDK. For more information, see [privacy manifest guide](https://docs.airship.com/platform/mobile/data-collection/ios-privacy-manifest/).

### Changes
- Added privacy manifest

## Version 17.2.2 September 1, 2023
Patch release that fixes an issue with the signing of the frameworks.

### Changes
- Fixed the certificate and included feature flags in signed frameworks.

## Version 17.2.1 August 29, 2023
Patch release that fixes an issue with not being able to update a Live Activity after it becomes stale. Apps that use `staleDate` with Live Activities should update.

### Changes
- Continue to track a Live Activity after it becomes stale

## Version 17.2.0 August 25, 2023
Minor release that fixes a reporting issue with hold out groups and In-App Messaging. 17.2.0 will be the minimum version required for global hold out groups.

### Changes
- Fixed reporting issue with hold out groups and In-App Messaging
- Added a new `NativeBridgeActionRunner` that can be passed into a `NativeBridge` instance to customize action running
- Added frameworks signing
- Fixed a remote-data crash during init
- Fixed Message Center sometimes not loading a message when opened from a push notification

## Version 16.12.4, August 29, 2023
Patch release that fixes an issue with not being able to update a Live Activity after it becomes stale. Apps that use `staleDate` with Live Activities should update.

### Changes
- Continue to track a Live Activity after it becomes stale
- Fixed channel registration issue with changing privacy manager flags during the first run

## Version 17.1.3 August 16, 2023
Patch release that fixes a reporting issue related to global holdout groups. Applications making use of global holdout groups should update.

### Changes
- Fixed experiment info reporting for global holdout groups

## Version 17.1.2 August 11, 2023
Patch release that fixes an issue with Xcode 15 due to a WKNavigationDelegate protocol conformance issue with the AirshipNativeBridge. Applications that are facing Airship build errors with Xcode 15 should update.

### Changes
- Fixed WKNavigationDelegate protocol issue

## Version 17.1.1 August 4, 2023
Patch release that fixes a possible delay with channel creation if the enabled flags on privacy manager changes before the channel is able to be created.

### Changes
- Fixed channel registration issue with privacy manager
- Fixed missing AirshipFeatureFlags xcframework in the Airship.zip

## Version 17.1.0 July 31, 2023
Minor release that adds support for global holdout groups in In-App experiences and support for feature flags.

### Changes
- Added new feature flag module `AirshipFeatureFlags`
- Added support for global holdout groups
- Fixed crash with deep links from an HTML based message
- Fixed a VoiceOver IAA issue where the content behind the IAA was being read

## Version 16.12.3, July 11, 2023
Patch release that works around a compiler issue with Xcode 15 beta and a Message Center issue with setting the navigation bar item tint.

### Changes
- Fix message center navigation item tint
- Added workaround for Xcode 15 beta compile issue

## Version 17.0.3 July 10, 2023
Patch release that fixes an issue with URL allow lists defaulting to allowing all URLs if calling takeOff with a config instance.

### Changes
- Fixed URL allow list issue
- Added workaround for Xcode 15 beta compile issue


## Version 17.0.2 July 2, 2023
Patch release that fixes an issue with modular header on podspec for AirshipServiceExtension and AirshipContentExtension, an issue deep linking to a deleted Message Center message, and fixes a regression with the share action. Applications that are using 17.0.1 or older should update.

### Changes
- Enable modular header for AirshipServiceExtension and AirshipContentExtension
- Fixed issue with a navigation loop to a deleted Message Center message
- Removed unused `applyIf` extension to avoid potential conflicts
- Fixed share action regression


## Version 16.12.2 June 28, 2023
Patch release that fixes an issue with modular header on podspec for AirshipServiceExtension and AirshipContentExtension and a channel registration issue where if the channel's metadata changes during an update task, a new task would not be queued to sync with Airship until the next foreground.

### Changes
- Enable modular header for AirshipServiceExtension and AirshipContentExtension
- Fixed channel registration task queuing

## Version 17.0.1 June 16, 2023
Patch release that addresses potential ambiguous use errors and improves Message Center module documentation.
Apps upgrading to SDK 17.0.0 should update to 17.0.1 instead.

### Changes
- Fixed potential `ambiguous use of overlay()` errors when using SwiftUI
- Improved Message Center module documentation

## Version 17.0.0 June 15, 2023
Major SDK release that adds support for Stories, In-App experiences downstream of a sequence in Journeys, and improves SDK auth.

This release brings several breaking changes throughout the codebase as we continue the transition from Objective-C to Swift, and as we start adopting structured concurrency.

The Airship SDK now requires iOS 14+ as the minimum deployment version and Xcode 14.3+

### Changes
- Added support for Stories, a new format for Scenes
- Added support for In-App experiences downstream of a sequence in Journeys
- Updated minimum deployment version to iOS 14
- Message Center module has been rewritten in Swift
- The provided Message Center UI has been rewritten in Swift & SwiftUI
- The provided Preference Center UI has been rewritten in SwiftUI
- Accengage, Chat, and Location modules have been removed
- ExtendedActions module has been removed and actions have been merged into other modules
- A majority of the completionHandler APIs have been replaced with `async` functions
- Renamed several classes throughout the SDK to prevent API collisions for simple classes, e.g. Config -> AirshipConfig, Channel -> AirshipChannel, etc.
- Fixed several `sendable` warnings throughout codebase
- Video improvements for Scenes
- Added a new PushNotificationStatus publisher that provides the current status of push notifications
- Actions rewritten to be sendable and are now only available from Swift
- Improved SDK auth
- Default In-App Automation display interval has been changed from 30 seconds to 0 seconds
- The SDK Allow list has been updated to allow opening all URLs by default if neither `urlAllowList` or `urlAllowListScopeOpen` have been set in the config. Media URLs for In-App experiences are no longer checked on the allow list. Youtube URLs have been removed from the default `urlAllowListScopeOpen`.

## Version 16.12.1, June 14, 2023
Patch release that fixes app deep links that use the `uairship://` prefix. Any `uairship://` deep links that are not handled by Airship directly will now be delivered to the `DeepLinkDelegate`.

### Changes
- Allow the `DeepLinkDelegate` to process unhandled `uairship://` deep links

## Version 16.12.0 June 12, 2023
Minor release that adds `aspectRatio` to HTML and Modal IAA styles and a new config option `autoPauseInAppAutomationOnLaunch` to always pause IAA during app
init to be enabled later.

### Changes
- Fixed channel restore from encrypted backups
- Added aspectRatio to HTML and Modal IAA styles
- Added `autoPauseInAppAutomationOnLaunch` config option
- Fixed parsing deep link and open external URLs that contain invalid URL characters

## Version 16.11.3 March 24, 2023
Patch release that fixing Contact update merging order, improves Scene/Survey accessibility and reporting.

### Changes
- Fixed Contact update merge order, resolving a Preference Center bug that could lead to unexpected subscription states in some circumstances.
- Improved Scene/Survey accessibility and fixed a reporting bug related to form display events.
- Fixed an issue with downgrading to a version older than 16.10.1 would cause the channel to be recreated.
- Added support for transparent WebView backgrounds in HTML In-App Automations

## Version 16.11.2 March 2, 2023
Patch release that fixes a regression introduced in 16.11.0 that disables Survey's submit button and inputs, and added accessibility font scaling to Scenes & Surveys.

### Changes
- Scale fonts for Scenes & Surveys
- Fixed Survey enablement regression

## Version 16.11.1 February 28, 2023
Patch release that exposes some Preference Center classes to Objective-C.

### Changes
- Exposes `UAPreferenceCenterResources`, `UAPreferenceCenterViewController` and `UAPreferenceAlertItemButton`to obj-c.

## Version 16.11.0 February 22, 2023
Minor release that fixes a potential channel restore issue on second run. The impact should be small since the channel create will return the same channel ID if the app has a device token or the app installed the Message Center module. 

### Changes
- Fixed app restore detection false positive on second run
- Added new optional `PushNotificationDelegate` method `extendPresentationOptions(_:notification:completionHandler)` that allows returning foreground presentation options with a callback instead of synchronously
- Added new `Config` method `validate(logIssues:)` to prevent logging on the config.
- Fixed nil URL log message when attempting to create a channel on the first run. The channel will now wait until the URL is available before attempting to be created. This should not cause any real difference in behavior, it only prevents the log message from being logged.
- Fixed Xcode 14.3 beta build issues

## Version 16.10.7 January 17, 2023
Patch release that adds a potential mitigation for some iOS 16 devices crashing when reading and writing to UserDefaults. We have not been able to reproduce the issue and seems limited to a small number of iOS 16 devices.

### Changes
- Added potential mitigation for a UserDefaults crash that is occurring on some iOS 16 devices.
- Specify the classes when using `'NSKeyedUnarchiver`.

## Version 16.10.6 December 5, 2022
Patch release that fixes Airship not performing network operations until next app foreground when triggered in the background.

### Changes
- Fixed background initiated operations.

## Version 16.10.5 November 30, 2022
Patch release with several fixes for Message Center, attributes, 
and In-App Automation.

### Changes
- Fixed issue with setting attributes to `0` or `1`.
- Fixed message getters in the JS native bridge when using Message Center.
- Updated the window levels to normal for IAA, Preference Center, and Message Center. This avoid conflicts with full screen video and other alert level windows.
- Fixed share action dialog from closing when an IAA is dismissed.



## Version 16.10.4 November 22, 2022
Patch release that fixes a regression with Scenes and Surveys next page button enablement. Apps on 16.10.1-16.10.3 that use Scenes & Surveys should update.

### Changes
- Fix pager button enablement

## Version 16.10.3 November 15, 2022
Patch release that fixes checking for notification opt-in when disabling the config option requestAuthorizationToUseNotifications.

### Changes
- Check for notification opt-in on active, not just transition to foreground.

## Version 16.10.2 November 7, 2022
Patch release to fix a delay when creating the Airship channel on first run. Apps that are using 16.10.1 or `requireInitialRemoteConfigEnabled` config should update.

### Changes
- Fixed channel creation delay on first run

## Version 16.10.1 November 3, 2022

Patch release that significantly speeds up SDK build time, fixes issues
with automatic setup for SwiftUI apps, and improves Scene & Surveys.

### Changes
- Fixed issues causing slow build times. The compile swift step is now ~6x faster.
- Fixed issues calling the original app delegate methods when the app delegate is set using UIApplicationDelegateAdaptor in a SwiftUI app.
- Moved Airship Keystore data to its own service bucket to avoid being accidentally deleted by other plugins/apps.
- Improved Scene text input focus on iOS 16.
- Improved gif rendering in Scenes & Surveys.
 
## Version 16.10.0 October 24, 2022

Adds support for live activity and custom Airship domains.

### Changes
- Adds support for live activities (when built with Xcode 14.1+)
- Adds support for setting the initialConfigURL when using custom domains
- Fixed OOTB Message Center deep linking to a Message on first display
- Fixed logging live activities update as an error instead of debug

## Version 16.10.0-beta October 6, 2022

Beta release for SDK 16.10.0 that adds support for live activities. To support live activities, you must call restore once after takeOff during `application(_:didFinishLaunchingWithOptions:)` with all the live activity types that you
might track with Airship:

```
  Airship.takeOff(config, launchOptions: launchOptions)

  Task {
      await Airship.channel.restoreLiveActivityTracking { restorer in
          await restorer.restore(
            forType: Activity<DeliveryAttributes>.self
          )
          await restorer.restore(
            forType: Activity<SomeOtherAttributes>.self
          )
      }
  }
```

Then whenever you want Airship to track an activity, call trackLiveActivity on the channel instance with the name of the activity:

```
  Task {
      await Airship.channel.trackLiveActivity(
          activity,
          name: "my-neat-activity"
      )
  }
```

You will then be able to send updates through the Airship Push API to the live activity using the name `my-neat-activity`.

## Version 16.9.4 October 5, 2022

Patch release that fixes Survey Attributes not being stored properly for radio buttons.

## Version 16.9.3 September 2, 2022

Patch release that fixes an IAA banner issue and renames an internal `JSON` enum to avoid conflicts.

## Version 16.9.2 August 15, 2022

Patch release that prevents Carthage from building internal targets and adds prebuild Carthage xcframeworks to the release. Apps using Carthage experiencing long builds should update.

###
- Replaced AirshipRelease* targets with Aggregate targets
- Added prebuilt Carthage xcframework distribution to Github releases

## Version 16.9.1 August 4, 2022

Patch release to rename an internal `Task` protocol to avoid conflicts with Swift concurrency Tasks.

### Changes
- Rename Task to AirshipTask to avoid name conflicts

## Version 16.9.0 July 29, 2022

Minor release that fixes the subscription list action and makes it possible to replace all Airship
location integration with a location permissions delegate. The location module will be removed in
SDK 17.

### Changes
- Location integration with Airship can be replaced with setting a location permission delegate on `PermissionsManager`.
- Fixed subscription list action.

## Version 16.8.0 June 30, 2022

Minor release that fixes several issues and adds support for custom log handler for Airship logs.

### Changes
- Added new AirshipLogHandler protocol that can be used to override Airship logging.
- Fixed custom preference center background color not applying to the entire preference center.
- Fixed message center "No messages" label visibility in dark mode.
- Fixed Preference Center to always display the correct toggle states when navigating away and back to Preference Center under poor network conditions.
- Fixed thread optimization warnings in Xcode 14.
- Changed the landing page and HTML IAA window to be marked as hidden on dismiss.
- Enabled autoplay videos in any Airship webviews. 


## Version 16.7.0 May 16, 2022

Minor release that fixes build issues with Xcode 13.3 and adds missing obj-c class prefix to the `UAPreferenceCenterComponent` class. 

### Changes
- Fixed class collision with CarbonCore.framework
- Fixed build issues with Xcode 13.3

## Version 16.6.0 May 4, 2022
Minor release that adds support for randomizing response order in a Survey, adds a new delegate method to InAppMessageManager that controls when a message can be displayed, and fixes several issues with Scenes & Surveys reporting. Apps using Scenes & Surveys should update.

### Changes
- Added new delegate method to `UAInAppMessagingDelegate` that can control when a message is able to be displayed.
- Added support for randomizing Survey responses.
- Added subscription list action.
- Updated localizations. All strings within the SDK are now localized in 48 different languages.
- Improved accessibility with OOTB Message Center UI.
- Updated Landing Page, HTML In-App messages, and Modal In-App Messages to have a more deterministic size when rendering not as full screen. Messages will grow to a max of 420x720 points with 24 leading, 48 top, 24 trailing, and 48 bottom padding. 
- Moved Preference Center and Message Center OOTB UI to use its own window instead of the current key window.
- In-App rules will now attempt to refresh before displaying. This change should reduce the chances of showing out of data or cancelled in-app automations, scenes, or surveys when background refresh is disabled.
- Fixed reporting issue with a single page Scene.
- Fixed rendering issues for Scenes & Surveys.
- Fixed deep links that contain invalid characters by encoding those deep links.
- Fixed potential main thread deadlock when modifying tags, attributes, and subscription lists. The deadlock will only happen if the app is modifying the data on the main queue while a previous change is being uploaded and the device is observing `NSUserDefaultsDidChangeNotification` on the main queue.
- Fixed strongly linking Network.framework on older iOS versions.


## Version 16.5.1 April 4, 2022
Patch release to fix a crash introduced in 16.5.0 on app restore on different devices. Apps running 16.5.0 should update.

### Changes
- Fixed crash with app restores.

## Version 16.5.0 March 29, 2022

A minor release that adds a style option to allow In-App Automation messages to be full screen on large devices, fixes an issue with iCloud backups recovering the same channel ID, and includes several In-App message fixes.

### Changes
- Added `extendFullScreenLargeDevice` to HTML and Modal styles sheets to allow displaying an In-App Automation as full screen on large devices.
- Fixed In-App Message localization.
- Fixed In-App Automation video inline playback.
- Fixed channel ID being restored from an iCloud backup.


## Version 16.4.0 February 24, 2022

A minor release that fixes a potential crash with message center, marks methods on PreferenceCenterViewController as open, and includes new styles for PreferenceCenterViewController. Apps that are experiencing crashes due to message center should update.

### Changes
- Added new styles for PreferenceCenterViewController.
- Mark methods as open on PreferenceCenterViewController to make overriding possible.
- Automatically refresh PreferenceCenterViewController if the preference center ID changes.
- Fixes notification options if migrating from a 14.x SDK when provision auth is used.
- Fixed typos and awkward objective-c names for manual App integration methods.
- Removed duplicate framework linker for UserNotifications in Swift.package

## Version 16.3.1 February 17, 2022

A patch release that fixes channel tags not updating til next app init without calling updateRegistration.

### Changes
- Made ContactSubscriptionItem.scopes accessible to objective-c
- PreferenceCenterViewController init method is now public
- Modifying channel tags will now queue up a channel registration update


## Version 16.3.0 February 8, 2022

A minor release that adds support for multi-channel Preference Center. Currently, these features are only available to customers in Airship's Special Access Program. Please reach out to your account manager for more details.

## Changes
- Added support for multi-channel Preference Center.
- Added scoped subscription lists to contacts.
- Added methods to associate email, SMS, and open channels to a contact.

## Version 16.2.0 January 24, 2022

A minor release that adds support for two new features, Scenes and Surveys. Currently, these features are only available to customers in Airship's Special Access Program. Please reach out to your account manager for more details.

### Changes
- Added support for Scenes and Surveys
- Fixed In-App Automation session trigger skipping sessions when automations are paused then resumed
- Split pod AirshipExtensions into AirshipServiceExtension and AirshipContentExtension

## Version 16.1.2 December 21, 2021
Patch release that fixes a contact update issue resulting in subsequent update operations not being executed.

### Changes
- Fixes a contact update issue resulting in subsequent update operations not being executed.

## Version 16.1.1 December 1, 2021
Patch release that fixes a styling issue with message center on iOS 15, running actions from a notification action button, and adds
the AirshipPreferenceCenter.xcframework.

### Changes
- Fixed Message Center navigation style on iOS 15
- Fixed running actions from a notification action button
- Fixed channel registration causing extra attribute operations in the RTDS stream
- Added AirshipPreferenceCenter.xcframework to the zip distribution

## Version 16.1.0 November 15, 2021
Minor release that fixes styling preference center, adds a new chat action, and fixes running actions in a HTML In-App Automation (including landing pages). Apps that are on SDK 15.0 - 16.0.3 that use actions in HTML In-App Automations should update.

### Changes
- Fixed native bridge actions for IAA and Landing Pages
- Fixed styling issues with preference center
- Added tint color for preference center switches
- Added send chat action

## Version 16.0.3 November 8, 2021
Patch release to fix background push not being enabled by default in SDk 15/16. Apps can either update to this version or enable background with `Airship.push.backgroundPushEnabled = true`.

### Changes
- Enable background push by default

## Version 16.0.2 November 3, 2021
Patch release that fixes preferences resetting when upgrading to SDK 15/16. This update will restore old preferences that have not been modified in the new SDK version.

**Apps that have migrated to SDK 15.0.0-16.0.1 should update. Apps currently on version 14.8.0 and below should only migrate to 16.0.2 to avoid a bug in versions 15.0.0-16.0.1.**

### Changes
- Restore preferences from SDK 14.x and older
- Added back missing Airship ready notification

## Version 16.0.1 October 19, 2021

**Due to a bug that mishandles persisted SDK settings, apps that are migrating from SDK 14.8.0 or older should avoid this version and instead use SDK 16.0.2 or newer.**

Patch release that fixes an IAA bug.

### Changes
- Fixed a bug with IAA not displayed after setting the isPaused to false.
- Fixed a rare crash at the application launch. 
- Remove some log.

## Version 16.0.0 September 30, 2021

**Due to a bug that mishandles persisted SDK settings, apps that are migrating from SDK 14.8.0 or older should avoid this version and instead use SDK 16.0.2 or newer.**

Major SDK release to address a conflict with the class and package `Airship` on CocoaPods. The import for Cocoapods has been changed from `Airship` to `AirshipKit`. No other breaking API changes have been introduced in this release.

### Changes
- Changed CocoaPods import to `AirshipKit`
- Added support for simple deep links for AirshipChat module
- Fixed parsing `enabledFeatures` in `AirshipConfig.plist`
- Fixed forward delegate on native bridge calling the decision handler multiple times
- Fixed missing message center and automation methods if they referenced `Disposable` or `Padding` when using Swift and SPM
- Fixed deprecation warnings for NamedUser.

## Version 15.0.1 September 15, 2021

**Due to a bug that mishandles persisted SDK settings, apps that are migrating from SDK 14.8.0 or older should avoid this version and instead use SDK 16.0.2 or newer.**

Patch release fixing a crash when setting date attributes. Apps using 15.0.0 should update. 14.x remains unaffected.

### Changes
- Fixed a crash when setting date attributes.

## Version 15.0.0 September 14, 2021

**Due to a bug that mishandles persisted SDK settings, apps that are migrating from SDK 14.8.0 or older should avoid this version and instead use SDK 16.0.2 or newer.**

Major SDK release with several breaking changes, especially for Swift users. This release adds support for preference center, Contacts, iOS 15, and subscription lists.

### Changes
- Core module has been rewritten in Swift. During the rewrite, many of the method signatures, nullability, and classes have been updated to be more inline with Swift.
- Dropped the `UA` prefix for Swift.
- Added new module `AirshipPreferenceCenter`.
- Added subscription lists APIs for Channel.
- Added new editor APIs on Channel to modify tags and attributes to help batch updates.
- NamedUser component has been replaced by Contact, which allows setting data on a user without an external ID (Named User ID).
- Removed use of class load methods. Airship now requires passing in the launch options during takeOff.
- Removed `Airship.xcframework` and `Airship` SPM target. Apps should use the modular frameworks instead.
- Carthage and xcframework users will need to include a new module `AirshipBasement`.

## Version 14.8.0 October 14, 2021
Minor release that adds the support of new iOS 15 notification types and fixing an IAA bug.

### Changes
- Added the new notification types: time sensitive and scheduled delivery to the channel registration payload.
- Fixed a bug with IAA not displayed after setting the isPaused to false.

## Version 14.7.0 September 14, 2021
Minor release that adds iOS 15 support. This build requires Xcode 13.

### Changes
- Requires Xcode 13+
- Added new options to UANotificationCategory, UANotificationAction, and UAAuthorizedNotificationSettings for iOS 15.

## Version 14.6.2 September 10, 2021
Patch release fixing In-App Automation messages not displaying when the keyboard is visible on iOS 15 devices.

### Changes
- Fixed IAA conflict with iOS 15 keyboard


## Version 14.6.1 August 6, 2021
Patch release fixing KVO-related crashes in NSUserDefaults. Apps experiencing related crashes or having problems with SDK user defaults behavior are recommended to upgrade.

### Changes
- Migrated NSUserDefaults usage to a private suite name

## Version 14.6.0 July 30, 2021
Minor release adding support for Chat routing and fixing build issues in Xcode 13.

### Changes
- Added Chat routing support
- Resolved build warnings in Xcode 13
- Fixed SPM build errors in Xcode 13 beta 3 and above

## Version 14.5.2 July 12, 2021
Patch release fixing an issue with IAA banners displayed in hidden windows, fixing a race condition when loading Accengage notification categories, and changing the behavior of UAPush to persist notification options. Apps having issues with IAA banner display in multi-window UIs or apps using the Accengage module are encouraged to update.
 
### Changes
- IAA banners no longer display in hidden windows
- Fixed race condition loading Accengage notification categories
- Requested notification options are persisted between application runs

## Version 14.5.1 June 16, 2021
Patch release fixing archive issues with AirshpChat when using SPM, localization conflict issues in Cocoapods, and UI/localization issues in AirshipChat. Apps using SPM, Cocoapods or Live Chat are encouraged to upgrade.

### Changes
- Renamed files in AirshipChat to avoid conflicts during archival
- Changed Airship.podspec to use resource bundles for all modules
- Fixed a UI crash in AirshipChat in SPM and Cocoapods-based Swift apps
- Fixed default localization in AirshipChat

## Version 14.5.0 June 4, 2021
Minor release changing how the SDK handles data collection by introducing the privacy manager. Privacy manager allows fine-grained control over what data is allowed to be collected or accessed by the Airship SDK.

### Changes
- Added privacy manager
- Deprecated existing data collection flags

See the [Migration Guide](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration/migration-guide-14.5.md) and the [Data Collection docs](https://docs.airship.com/platform/ios/data-collection/) for further details.

## Version 14.4.2 June 2, 2021
Patch release that improves verbose logging for IAA for better debugging and fixes carthage and SPM issues with the live chat module.

### Changes
- Improve trace logs for IAA
- Exclude tests directory from SPM
- Fix Chat deployment target

## Version 14.4.1 May 7, 2021
Patch release with task manager and chat-related bugfixes. Applications seeing issues related to the task manager and applications using AirshipChat are encouraged to update.

### Changes
- Fixed a dispatch_sync bug that could trigger exceptions in the task manager
- Fixed a websocket connection deadlock in AirshipChat
- Fixed a bug in AirshipChat causing unreadable message text

## Version 14.4.0 April 26, 2021

Minor release that adds support for Airship Live Chat.

### Changes
- Added new AirshipChat module.
- Allow inline media playback in message center.
- Fixed automatic inProduction selection for catalyst apps.

## Version 14.3.1 April 5, 2021

Patch fixing an issue with AirshipAccengage that caused apps without a previous Accengage installation to miss first open analytics. Apps including the AirshipAccengage module and experiencing issues with first open data are encouraged to update.

### Changes
- Fixed first open issues with AirshpAccengage module

## Version 14.3.0 March 11, 2021

Minor release that improves background task management and drops support for uploading historic location data to Airship. The location module can still be used to listen for location updates within the app and will be deprecated in a future release.

### Changes
- AirshipLocation will no longer upload lat/longs to Airship.
- Reworked background task management.

## Version 14.2.3 February 5, 2021
Patch release fixing issues with direct opens with open external URL actions, and thread safety for the frequency limits data store. Applications experiencing problems with direct open counts and apps using frequency limits should update.

### Changes
- Fixed synchronization for frequency constraints
- Fixed edge case where launch notifictions with open external URL actions were not generating direct opens

## Version 14.2.2 January 13, 2021
Patch release that fixes issues with setting attributes on a named user if the named user ID contains invalid URL characters. Applications using attributes with named users that possibly contain invalid URL characters should update.

### Changes
- Fixed attributes updates when the named user has invalid URL characters.
- Fixed accessing UIApplication state on a background queue warning.
- Initial channel creation will wait up to 10 seconds for device token registration.


## Version 14.2.1 December 30, 2020
Patch release fixing sms: and tel: URL handling, and improving logging around push opt out status. Apps experiencing issues with sms or tel links in IAA or Message Center are encouraged to update.

### Changes
- Fixed handling of sms: and tel: URLs in the Native Bridge
- Detailed trace logging of push opt-out status

## Version 14.2.0 December 16, 2020
Minor release adding support for frequency limits and advanced segmentation to In-App Automation, as well as new custom event templates.

### Changes
- Added frequency limits support to IAA
- Added support for advanced IAA segmentation
- Added a new search event template
- Added wishlist options to retail event template
- Added tel: sms: and mailto: to default allow list settings
- IAA messages no longer redisplay if interrupted due to app termination
- Fixed maxWidth style overrides for IAA banners
- Fixed a bug handling grace periods for IAA schedule edits

## Version 14.1.3 - October 29, 2020
Patch release optimizing tag group cache usage in In-App-Automation, and fixing
an issue with direct opens for notification action buttons. Apps using named users
and IAA, or apps experiencing issues with direct open counts are encouraged to update.

### Changes
- IAA tag group cache is now cleared when a named user is associated or disassociated
- Fixed bug affecting direct open counts when using notification action buttons

## Version 14.0.1 - October 21, 2020
Patch release to fix a crash related to sending In-App Messages through push notifications. Applications running 14.0.0 that use In-App Messages should update.

## Version 14.1.2 - September 24, 2020
Patch release to fix a crash related to sending In-App Messages through push notifications. Applications running 14.0.0+ that use In-App Messages should update.

## Version 14.1.1 - September 17, 2020
Patch release fixing a crash in the Airship and AirshipAutomation XCFramework.
Apps using XCFrameworks should update.

### Changes
- Added missing resources to Airship and AirshipAutomation modules
- Fixed XCFrameworks build issues for AirshipAccengage
- Fixed sample app build issues when targeting macOS Catalyst

## Version 14.1.0 - September 15, 2020
Minor release that adds support for iOS 14 features and Swift package manager.

### Changes
- Requires Xcode 12+
- Swift package manager support
- Support for App Clips and ephemeral notification authorization
- Support for reduced accuracy location
- Support for list and banner notification types

## Version 14.0.0 - September 3, 2020
Airship SDK 14 is a major update that prepares our automation module to support future IAA enhancements, revamps the Channel Capture tool, and provides other improvements.

The majority of apps will only be effected by the new `UAURLAllowList` behavior changes.

### Changes
- **BEHAVIOR CHANGE** All URLs are not verified by default. Applications that use open URL action, landing pages, and custom in-app message image URLs will need to provide a list of URL patterns that match those URLs for SCOPE_OPEN_URL. The easiest way to go back to 13.x behavior is to add the wildcard symbol `*` to the array under the `URLAllowListScopeOpenURL` key in your AirshipConfig.plist.
- Channel Capture tool now detects a `knock` of 6 app opens in 30 seconds. Instead of displaying anything to the user, the tool will write the current channel ID to the clipboard.
- `UAWhitelist` class and terminology removed and replaced with `UAURLAllowList`.
- `UAActionAutomation` class and functionality has been moved to `UAInAppAutomation`, which covers both Action Automation and In-App Messages.
- In-App Automation APIs have been updated to support future IAA enhancements.
- Removed deprecated APIs.

See the [Migration Guide](https://github.com/urbanairship/ios-library/tree/main/Documentation/Migration/migration-guide-13-14.md) for further details.


## For older releases, see [CHANGELOG](https://github.com/urbanairship/ios-library/blob/13.5.6/CHANGELOG.md)
