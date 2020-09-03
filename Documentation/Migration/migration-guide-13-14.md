# Airship iOS SDK 13.2 to 14.0 Migration Guide

Airship SDK 14 is a major update that prepares our automation module to support future IAA enhancements, revamps our Channel Capture tool, improves support for Xcode 12 & iOS 14, and provides other improvements.

## UAWhitelist is now UAURLAllowList

We have renamed `UAWhitelist` to `UAURLAllowList`. In addition to the class, many properties, methods and constants have been renamed.

There are now three URLAllowList keys that can be added to `AirshipConfig.plist`:
- `URLAllowList`: The list used to validate which URLs can be opened or can load the JavaScript native bridge. This key was previously named `whitelist`.
- `URLAllowListScopeOpenURL`: The list used to validate which URLs can be opened.
- `URLAllowListScopeJavaScriptInterface`: The list used to validate which URLs can load the JavaScript native bridge.

The values for any of the three keys are arrays of patterns that are matched to the URL. See [UAURLAllowList](https://docs.airship.com/reference/libraries/ios/latest/Airship/Classes.html#/c:objc%28cs%29UAURLAllowList) for the syntax of the pattern entries.

---

### WARNING (Behavior Change)
**The `openURLWhitelistingEnabled` config key has been removed. OpenURL-scoped URLs are now always verified. This will likely cause the Open URL and Landing Page actions to no longer work if you are using the default for that key (`NO`). To fix this issue, add a wildcard (`*`) entry to the new `URLAllowListScopeOpenURL` key in AirshipConfig.plist. This will allow any URLs for those actions.**

---

## Automation Changes

### Standard In-App Messages

In `UALegacyInAppMessageBuilderExtender` the method `extendScheduleInfoBuilder:message:` has been renamed to [`extendScheduleBuilder:message:`](https://docs.airship.com/reference/libraries/ios/latest/Airship/Protocols/UALegacyInAppMessageBuilderExtender.html#/c:objc(pl)UALegacyInAppMessageBuilderExtender(im)extendScheduleBuilder:message:). It is passed a [`UAScheduleBuilder`](https://docs.airship.com/reference/libraries/ios/latest/Airship/Classes/UAScheduleBuilder.html) object instead of the now removed `UAInAppMessageScheduleInfoBuilder` object. All of the properties that used to exist in `UAInAppMessageScheduleInfoBuilder` are now available on ``UAScheduleBuilder`.

For example, the following is our pre-SDK 14 [Example UALegacyInAppMessageBuilderExtender](https://docs.airship.com/platform/ios/in-app-automation/#standard):

```objc
- (void)extendScheduleInfoBuilder:(UAInAppMessageScheduleInfoBuilder *)builder
                          message:(UALegacyInAppMessage *)message {
    builder.limit = 2;
}

- (void)extendMessageBuilder:(UAInAppMessageBuilder *)builder
                     message:(UALegacyInAppMessage *)message {
    UAInAppMessageBannerDisplayContent *bannerDisplayContent = (UAInAppMessageBannerDisplayContent *) builder.displayContent;
    [bannerDisplayContent extend:^(UAInAppMessageBannerDisplayContentBuilder * _Nonnull builder) {
        builder.borderRadiusPoints = 10;
    }];

    builder.displayContent = bannerDisplayContent;
}
```

The example updated for the new SDK 14 API:

```objc
- (void)extendScheduleBuilder:(UAScheduleBuilder *)builder
                      message:(UALegacyInAppMessage *)message {
    builder.limit = 2;
}

- (void)extendMessageBuilder:(UAInAppMessageBuilder *)builder
                     message:(UALegacyInAppMessage *)message {
    UAInAppMessageBannerDisplayContent *bannerDisplayContent = (UAInAppMessageBannerDisplayContent *) builder.displayContent;
    [bannerDisplayContent extend:^(UAInAppMessageBannerDisplayContentBuilder * _Nonnull builder) {
        builder.borderRadiusPoints = 10;
    }];

    builder.displayContent = bannerDisplayContent;
}
```

The required changes are limited to the method signature for `extendMessageBuilder:message:`. The builder code remains the same.

### In-App Automation API

The properties from the `UAInAppMessageScheduleInfo` class have been merged into the `UAInAppMessageSchedule` class. Instances are created using the `scheduleWithMessage:builderBlock:` class method.

- `UAInAppMessageAudience` has been renamed `UAScheduleAudience`, and has been moved from `UAInAppMessage` to `UAInAppMessageSchedule`. The `UAInAppMessageAudienceMissBehaviorType` enum has been renamed `UAScheduleAudienceMissBehaviorType`.
- `UAInAppMessage` no longer has an `identifier` property. The `UAInAppMessageSchedule` identifier property is now used instead.

Note: The first time SDK 14 runs it will migrate existing in-app automations, setting the schedule identifier of each existing schedule to the message's identifier, as long as the message identifiers are unique. If your app's message identifiers are all unique, they can be used as the schedule identifiers when accessing schedules after migration. If your message identifiers are not unique, follow this process to map your existing message identifiers to the new schedule identifiers:
1. During the migration, the existing message identifier and schedule identifier will be added to the metadata for each schedule, under the keys `com.urbanairship.original_message_id` and `com.urbanairship.original_schedule_id`, respectively.
2. After the migration, your code can use the methods in the [Retrieving In-App Automation Schedules](#retrieving-in-app-automation-schedules) section below to loop through all schedules, mapping your app's previous message and schedule identifiers to the new schedule identifiers.

#### Scheduling In-App Automation Schedules

```objc
// Schedule one in-app automation schedule
[[UAInAppAutomation shared] schedule:schedule completionHandler:^(BOOL result) {
    NSLog(@"Schedule result = %@", (result) ? @"YES" : @"NO");
}];

// Schedule multiple in-app automation schedule
[[UAInAppAutomation shared] scheduleMultiple:schedules completionHandler:^(BOOL result) {
    NSLog(@"Schedule multiple result = %@", (result) ? @"YES" : @"NO");
}];
```

#### Retrieving In-App Automation Schedules

```objc
[[UAInAppAutomation shared] getMessageScheduleWithID:identifier completionHandler:^(UAInAppMessageSchedule *schedule) {
    // get schedule
}];

[[UAInAppAutomation shared] getMessageSchedules:^(NSArray<UAInAppMessageSchedule *> *schedules) {
    // get all schedules
}];

[[UAInAppAutomation shared] getMessageSchedulesWithGroup:@"group_name" completionHandler:^(NSArray<UAInAppMessageSchedule *> *actionSchedules) {
    // get all schedules of the given group.
}];
```

#### Canceling In-App Automation Schedules

Methods for canceling a single schedule or a group of schedules have also been moved from `UAActionAutomation` to `UAInAppAutomation`. There is no longer a method for canceling all schedules.

```objc
// Cancels a schedule with the given identifier
[[UAInAppAutomation shared] cancelScheduleWithID:@"some_scheduled_identifier" completionHandler:^(BOOL result) {
    NSLog(@"Cancel result = %@", (result) ? @"YES" : @"NO");
}];

// Cancels all schedules of the given group
[[UAInAppAutomation shared] cancelMessageSchedulesWithGroup:@"some_group_name" completionHandler:^(BOOL result) {
    NSLog(@"Cancel result = %@", (result) ? @"YES" : @"NO");

}];
```

### Action Automation API

The `UAActionScheduleInfo` class has been replaced by the `UAActionSchedule` class. Instances are created using the `scheduleWithActions:builderBlock:` class method. Schedule the action schedule instance using `UAInAppAutomation`'s `schedule:completionHandler:` or `scheduleMultiple:completionHandler:` methods.

#### Scheduling Actions

The `UAActionAutomation` method `scheduleActions:completionHandler:` has been moved to `UAInAppAutomation` and renamed `schedule:completionHandler:`. It is passed a `UASchedule` object instead of the now removed `UAActionScheduleInfo`. All of the properties that used to exist in `UAActionScheduleInfo` are now available on ``UAScheduleBuilder`.

For example, the following is our pre-SDK 14 [scheduling actions example](https://docs.airship.com/platform/ios/advanced/action-automation/#scheduling-actions):

```objc
// Build the schedule info
UAActionScheduleInfo *scheduleInfo = [UAActionScheduleInfo actionScheduleInfoWithBuilderBlock:^(UAActionScheduleInfoBuilder *builder) {
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"name"];
    UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
    UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];

    UAScheduleTrigger *customEventTrigger = [UAScheduleTrigger customEventTriggerWithPredicate:predicate count:2];
    UAScheduleTrigger *foregroundEventTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];

    builder.actions = @{@"add_tags_action": @"my_tag"};
    builder.triggers = @[customEventTrigger, foregroundEventTrigger];
    builder.group = @"group_name";
    builder.limit = 4;
    builder.start = [NSDate dateWithTimeIntervalSinceNow:10];
    builder.end = [NSDate dateWithTimeIntervalSinceNow:1000];
}];

// Schedule the schedule info
[[UAirship automation] scheduleActions:scheduleInfo completionHandler:^(UASchedule *schedule) {
    NSLog(@"Unique schedule identifier: %@", schedule.identifier);
}];
```

The example updated for the new SDK 14 API:

```objc
// Build the action schedule
UAActionSchedule *schedule = [UAActionSchedule scheduleWithActions:@{@"add_tags_action": @"my_tag"} builderBlock:^(UAScheduleBuilder *builder) {
    UAJSONValueMatcher *valueMatcher = [UAJSONValueMatcher matcherWhereStringEquals:@"name"];
    UAJSONMatcher *jsonMatcher = [UAJSONMatcher matcherWithValueMatcher:valueMatcher scope:@[UACustomEventNameKey]];
    UAJSONPredicate *predicate = [UAJSONPredicate predicateWithJSONMatcher:jsonMatcher];

    UAScheduleTrigger *customEventTrigger = [UAScheduleTrigger customEventTriggerWithPredicate:predicate count:2];
    UAScheduleTrigger *foregroundEventTrigger = [UAScheduleTrigger foregroundTriggerWithCount:2];

    builder.triggers = @[customEventTrigger, foregroundEventTrigger];
    builder.group = @"group_name";
    builder.limit = 4;
    builder.start = [NSDate dateWithTimeIntervalSinceNow:10];
    builder.end = [NSDate dateWithTimeIntervalSinceNow:1000];
}];

// Schedule the action schedule
[[UAInAppAutomation shared] schedule:schedule completionHandler:^(BOOL result) {
    NSLog(@"Schedule result = %@", (result) ? @"YES" : @"NO");
}];
```

The required changes are in the `UAActionSchedule *schedule = ...` line, and in the call to and the completion handler for the `UAInAppAutomation` `schedule:completionHandler` method. The builder code remains the same.

#### Retrieving Action Schedules

Similarly, the methods for retrieving a single schedule, a group of schedules, or all schedules have moved from `UAActionAutomation` to `UAInAppAutomation`.

```objc
[[UAInAppAutomation shared] getActionScheduleWithID:identifier completionHandler:^(UAActionSchedule *schedule) {
    // get schedule
}];

[[UAInAppAutomation shared] getActionSchedules:^(NSArray<UAActionSchedule *> *schedules) {
    // get all schedules
}];

[[UAInAppAutomation shared] getActionSchedulesWithGroup:@"group_name" completionHandler:^(NSArray<UAActionSchedule *> *actionSchedules) {
    // get all schedules of the given group.
}];
```

#### Canceling Action Schedules

Methods for canceling a single schedule or a group of schedules have also been moved from `UAActionAutomation` to `UAInAppAutomation`. There is no longer a method for canceling all schedules.

```objc
// Cancels a schedule with the given identifier
[[UAInAppAutomation shared] cancelScheduleWithID:@"some_scheduled_identifier" completionHandler:^(BOOL result) {
    NSLog(@"Cancel result = %@", (result) ? @"YES" : @"NO");
}];

// Cancels all schedules of the given group
[[UAInAppAutomation shared] cancelActionSchedulesWithGroup:@"some_group_name" completionHandler:^(BOOL result) {
    NSLog(@"Cancel result = %@", (result) ? @"YES" : @"NO");

}];
```

## Channel Capture Changes

The [Channel Capture tool](https://docs.airship.com/platform/ios/advanced/channel-capture-tool/) has been completely revamped.

The channel capture tool now defaults to enabled unless disabled using the `channelCaptureEnabled` key in `AirshipConfig.plist`. When the channel capture tool is enabled, the user can "capture" the channel id by "knocking" 6 times within 30 seconds. The user knocks by moving the app from the background into the foreground, i.e. exiting the app and then running the app. When the channel channel is captured, it is copied to the clipboard with a leading "ua:". If there is no channel, only the "ua:" will be present. The channel will remain on the clipboard for 60 seconds.

The channel capture tool can be programatically enabled or disabled using the new `enable` property. This enable state no longer persists through app init, and will instead revert to the value of the  `channelCaptureEnabled` key in `AirshipConfig.plist`. It is no longer possible to enable channel capture for a specified amount of time.

The disable method has been removed. To programatically disable, simply set the `enable` property to `NO`.

The channel capture action has been removed. If your app depended on the channel capture action to enable or disable the channel capture tool, it will need to use another technique.

## Xcode 12 / iOS 14 support

The `UAMessageCenterStyle *style` property in our Message Center view classes conflicts with Apple's new iOS 14 style property `UISplitViewControllerStyle style` in `UISplitViewController`. To resolve the conflict, we have renamed our `style` property to `messageCenterStyle` in all Message Center view classes:

- `UADefaultMessageCenterListViewController`
- `UADefaultMessageCenterSplitViewController`
- `UADefaultMessageCenterUI`
- `UAMessageCenterListCell`

## Deprecated code

We have removed all code that was deprecated and targeted for removal in SDK 14. The following sections list what was removed and include recommended replacement functionality.

### Renamed classes and related files
| Old Name | Replacement |
| - | - |
| `UAMessageCenterListViewController` | `UADefaultMessageCenterListViewController` |
| `UAMessageCenterListViewController.xib` | `UADefaultMessageCenterListViewController.xib` |
| `UAMessageCenterMessageViewController` | `UADefaultMessageCenterMessageViewController` |
| `UAMessageCenterMessageViewController.xib` | `UADefaultMessageCenterMessageViewController.xib` |
| `UAMessageCenterMessageViewProtocol.h` | The protocol has been removed. Use properties and methods of `UADefaultMessageCenterMessageViewController`. |
| `UAMessageCenterSplitViewController` | `UADefaultMessageCenterSplitViewController` |

### Renamed constants
| Old Name | Replacement |
| - | - |
| `kUAAddCustomEventActionDefaultRegistryName` | `UAAddCustomEventActionDefaultRegistryName` |
| `kUAAddTagsActionDefaultRegistryAlias` | `UAAddTagsActionDefaultRegistryAlias` |
| `kUAAddTagsActionDefaultRegistryName` | `UAAddTagsActionDefaultRegistryName` |
| `kUACancelSchedulesActionDefaultRegistryAlias` | `UACancelSchedulesActionDefaultRegistryAlias` |
| `kUACancelSchedulesActionDefaultRegistryName` | `UACancelSchedulesActionDefaultRegistryName` |
| `kUACircularRegionKey` | `UACircularRegionKey` |
| `kUACircularRegionMaxRadius` | `UACircularRegionMaxRadius` |
| `kUACircularRegionMinRadius` | `UACircularRegionMinRadius` |
| `kUACircularRegionRadiusKey` | `UACircularRegionRadiusKey` |
| `kUAConnectionTypeCell` | `UAConnectionTypeCell` |
| `kUAConnectionTypeNone` | `UAConnectionTypeNone` |
| `kUAConnectionTypeWifi` | `UAConnectionTypeWifi` |
| `kUADeepLinkActionDefaultRegistryAlias` | `UADeepLinkActionDefaultRegistryAlias` |
| `kUADeepLinkActionDefaultRegistryName` | `UADeepLinkActionDefaultRegistryName` |
| `kUAEnableFeatureActionDefaultRegistryAlias` | `UAEnableFeatureActionDefaultRegistryAlias` |
| `kUAEnableFeatureActionDefaultRegistryName` | `UAEnableFeatureActionDefaultRegistryName` |
| `kUAFetchDeviceInfoActionDefaultRegistryAlias` | `UAFetchDeviceInfoActionDefaultRegistryAlias` |
| `kUAFetchDeviceInfoActionDefaultRegistryName` | `UAFetchDeviceInfoActionDefaultRegistryName` |
| `kUAInteractionMCRAP` | `UAInteractionMCRAP` |
| `kUALandingPageActionDefaultRegistryAlias` | `UALandingPageActionDefaultRegistryAlias` |
| `kUALandingPageActionDefaultRegistryName` | `UALandingPageActionDefaultRegistryName` |
| `kUAOpenExternalURLActionDefaultRegistryAlias` | `UAOpenExternalURLActionDefaultRegistryAlias` |
| `kUAOpenExternalURLActionDefaultRegistryName` | `UAOpenExternalURLActionDefaultRegistryName` |
| `kUAPasteboardActionDefaultRegistryAlias` | `UAPasteboardActionDefaultRegistryAlias` |
| `kUAPasteboardActionDefaultRegistryName` | `UAPasteboardActionDefaultRegistryName` |
| `kUAProximityRegionIDKey` | `UAProximityRegionIDKey` |
| `kUAProximityRegionKey` | `UAProximityRegionKey` |
| `kUAProximityRegionMajorKey` | `UAProximityRegionMajorKey` |
| `kUAProximityRegionMaxRSSI` | `UAProximityRegionMaxRSSI` |
| `kUAProximityRegionMinRSSI` | `UAProximityRegionMinRSSI` |
| `kUAProximityRegionMinorKey` | `UAProximityRegionMinorKey` |
| `kUAProximityRegionRSSIKey` | `UAProximityRegionRSSIKey` |
| `kUARateAppActionDefaultRegistryAlias` | `UARateAppActionDefaultRegistryAlias` |
| `kUARateAppActionDefaultRegistryName` | `UARateAppActionDefaultRegistryName` |
| `kUARegionBoundaryEventEnterValue` | `UARegionBoundaryEventEnterValue` |
| `kUARegionBoundaryEventExitValue` | `UARegionBoundaryEventExitValue` |
| `kUARegionBoundaryEventKey` | `UARegionBoundaryEventKey` |
| `kUARegionEventMaxCharacters` | `UARegionEventMaxCharacters` |
| `kUARegionEventMaxLatitude` | `UARegionEventMaxLatitude` |
| `kUARegionEventMaxLongitude` | `UARegionEventMaxLongitude` |
| `kUARegionEventMinCharacters` | `UARegionEventMinCharacters` |
| `kUARegionEventMinLatitude` | `UARegionEventMinLatitude` |
| `kUARegionEventMinLongitude` | `UARegionEventMinLongitude` |
| `kUARegionEventType` | `UARegionEventType` |
| `kUARegionIDKey` | `UARegionIDKey` |
| `kUARegionLatitudeKey` | `UARegionLatitudeKey` |
| `kUARegionLongitudeKey` | `UARegionLongitudeKey` |
| `kUARegionSourceKey` | `UARegionSourceKey` |
| `kUARemoveTagsActionDefaultRegistryAlias` | `UARemoveTagsActionDefaultRegistryAlias` |
| `kUARemoveTagsActionDefaultRegistryName` | `UARemoveTagsActionDefaultRegistryName` |
| `kUAScheduleActionDefaultRegistryAlias` | `UAScheduleActionDefaultRegistryAlias` |
| `kUAScheduleActionDefaultRegistryName` | `UAScheduleActionDefaultRegistryName` |
| `kUAShareActionDefaultRegistryAlias` | `UAShareActionDefaultRegistryAlias` |
| `kUAShareActionDefaultRegistryName` | `UAShareActionDefaultRegistryName` |
| `kUAWalletActionDefaultRegistryAlias` | `UAWalletActionDefaultRegistryAlias` |
| `kUAWalletActionDefaultRegistryName` | `UAWalletActionDefaultRegistryName` |

### UACustomEvent methods removed

The following methods used to set typed properties on `UACustomEvent` have been removed.
- `setBoolProperty:forKey:`
- `setStringProperty:forKey:`
- `setNumberProperty:forKey:`
- `setStringArrayProperty:forKey:`

Instead use the `properties` property of `UACustomEvent`. `properties` must be valid JSON:
- All objects are `NSString`, `NSNumber`, `NSArray`, `NSDictionary`, or `NSNull`
- All dictionary keys are `NSStrings`
- `NSNumbers` are not `NaN` or infinity

### UAPush methods and properties renamed and moved

`presentationOptionsForNotification:` has been renamed `extendPresentationOptions:notification:`.

#### Methods moved to UAChannel

- `addTag:`
- `addTags:`
- `removeTag:`
- `removeTags:`
- `addTags:group:`
- `removeTags:group:`
- `setTags:group:`
- `enableChannelCreation`

#### Properties moved to UAChannel

- `channelID` (renamed `identifier`)
- `tags`
- `channelTagRegistrationEnabled`