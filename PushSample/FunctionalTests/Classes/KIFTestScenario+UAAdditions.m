/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "KIFTestScenario+UAAdditions.h"

#import "KIFTestStep+UAAdditions.h"

#import "UAPush.h"
#import "UAUtils.h"
#import "UAPushClient.h"
#import "UATestPushDelegate.h"

#define kPushRegistrationWait 10.0
#define kAliasTagsRegistrationWait 30.0
#define kPushWait 90.0

@implementation KIFTestScenario (UAAdditions)

+ (id)scenarioToEnablePush {
    
    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that push can be enabled in the settings screen."];
    
    // enable push via the UI
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Push Settings"]];
    [scenario addStep:[KIFTestStep stepToSetOn:YES forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"]];

    // save push enabled
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton]];

    // wait for registration
    [scenario addStep:[KIFTestStep stepToWaitForTimeInterval:kPushRegistrationWait description:@"Wait for the registration to succeed."]];

    // verify push is enabled
    [scenario addStep:[KIFTestStep stepToVerifyPushEnabled:YES]];

    return scenario;
}

+ (id)scenarioToReceiveUnicastPush {
    
    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that a unicast push is received and properly handled."];
    
    // Now send a unicast push to the device token and verify we received the notification
    [scenario addStepsFromArray:[KIFTestStep stepsToSendAndWaitForNotification:@"Send a unicast Push" sendPushBlock:^(NSString *alertID) {
        [UAPushClient sendAlert:alertID toDeviceToken:[UAPush shared].deviceToken];
    }]];

    return scenario;
}

+ (id)scenarioToReceiveBroadcastPush {
    
    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that a broadcast push is received and properly handled."];

    // Now send a broadcast push and verify we received the notification
    [scenario addStepsFromArray:[KIFTestStep stepsToSendAndWaitForNotification:@"Send a broadcast Push" sendPushBlock:^(NSString *alertID) {
        [UAPushClient sendBroadcastAlert:alertID];
    }]];

    return scenario;
}

+ (id)scenarioToSetAlias {

    NSString *uniqueAlias = [[UAUtils UUID] lowercaseString];

    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that an alias can be set and we can receive a push"];

    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Token Settings"]];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Alias"]];

    // edit the alias with the uniqueAlias
    [scenario addStep:[KIFTestStep stepToEnterText:uniqueAlias intoViewWithAccessibilityLabel:@"Edit Alias"]];

    // save the alias and go back
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton]];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton]];

    [scenario addStep:[KIFTestStep stepToWaitForTimeInterval:kAliasTagsRegistrationWait description:@"Wait for the registration to succeed."]];

    // Now send a push to the alias and verify we received the notification
    [scenario addStepsFromArray:[KIFTestStep stepsToSendAndWaitForNotification:@"Send Push to alias" sendPushBlock:^(NSString *alertID) {
        [UAPushClient sendAlert:alertID toAlias:uniqueAlias];
    }]];

    return scenario;
}

+ (id)scenarioToSetTag {
    
    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that a tag can be set."];

    NSString *uniqueTag = [[UAUtils UUID] lowercaseString];

    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Token Settings"]];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Tags"]];

    // delete any existing tags
    for (NSString *tag in [UAPush shared].tags) {
        [scenario addStep:
            [KIFTestStep stepToTapViewWithAccessibilityLabel:[NSString stringWithFormat:@"Delete %@", tag]
                                                      traits:UIAccessibilityTraitButton]];

        // Detect the iOS version at run-time using feature detection of NSURLSession (added in iOS 7).
        // iOS 7 UI requires another tap on 'Delete' button, while older versions need to confirm deletion.
        if ([NSURLSession class]) {
            [scenario addStep:
             [KIFTestStep stepToTapViewWithAccessibilityLabel:[NSString stringWithFormat:@"Delete"]
                                                       traits:UIAccessibilityTraitButton]];
        } else {
            [scenario addStep:
             [KIFTestStep stepToTapViewWithAccessibilityLabel:[NSString stringWithFormat:@"Confirm Deletion for %@", tag]
                                                       traits:UIAccessibilityTraitButton]];
        }
    }

    // add a tag with the uniqueTag
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Add" traits:UIAccessibilityTraitButton]];
    [scenario addStep:[KIFTestStep stepToEnterText:uniqueTag intoViewWithAccessibilityLabel:@"Custom Tag Input"]];

    // save the tag
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton]];

    // todo: verify that the tag exists

    // back to token screen
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton]];

    // back to main screen
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton]];

    // wait for registration
    [scenario addStep:[KIFTestStep stepToWaitForTimeInterval:kAliasTagsRegistrationWait description:@"Wait for the registration to succeed."]];

    // Now send a push to the tag and verify we received the notification
    [scenario addStepsFromArray:[KIFTestStep stepsToSendAndWaitForNotification:@"Send Push to tag" sendPushBlock:^(NSString *alertID) {
        [UAPushClient sendAlert:alertID toTag:uniqueTag];
    }]];
    
    return scenario;
}

+ (id)scenarioToDisablePush {
    
    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that push can be disabled in the settings screen."];

    // disable push via the UI
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Push Settings"]];
    [scenario addStep:[KIFTestStep stepToSetOn:NO forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"]];

    // save push disabled
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton]];

    // verify push is disabled
    [scenario addStep:[KIFTestStep stepToVerifyPushEnabled:NO]];

    return scenario;
}

@end
