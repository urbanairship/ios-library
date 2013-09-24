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

#import "PushSampleKIFTests.h"
#import "UA_Reachability.h"
#import "UAPush.h"
#import "UATestPushDelegate.h"
#import "KIFUITestActor+UAAdditions.h"
#import "UAPushClient.h"
#import "UAUtils.h"

#define kPushRegistrationWait 10.0
#define kAliasTagsRegistrationWait 30.0

static NSObject<UAPushNotificationDelegate> *pushDelegate;

@implementation PushSampleKIFTests

- (void)beforeAll {
    NSLog(@"-----------------------------------------------------------------------------------------------");
    NSLog(@"Test that push can be enabled in the settings screen and register for remote notifications.");
    NSLog(@"-----------------------------------------------------------------------------------------------");

    // Capture connection type using Reachability
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    if (netStatus == UA_NotReachable) {
        NSLog(@"The Internet connection appears to be offline. Abort KIF tests.");
        exit(EXIT_FAILURE);
    }

    pushDelegate = [[UATestPushDelegate alloc] init];
    [UAPush shared].pushNotificationDelegate = pushDelegate;

    // enable push via the UI
    [tester tapViewWithAccessibilityLabel:@"Push Settings"];
    [tester setOn:YES forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"];
    [tester waitForViewWithAccessibilityLabel:@"Push Notifications Enabled" value:@"1" traits:UIAccessibilityTraitNone];

    // save push enabled
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // wait for registration
    NSLog(@"Wait for the registration to succeed.");
    [tester waitForTimeInterval:kPushRegistrationWait];

    // verify push is enabled
    [tester verifyPushEnabled:YES];
}

- (void)afterAll {
    NSLog(@"-----------------------------------------------------------------------------------------------");
    NSLog(@"Test that push can be disabled in the settings screen and unregister from remote notifications.");
    NSLog(@"-----------------------------------------------------------------------------------------------");

    // disable push via the UI
    [tester tapViewWithAccessibilityLabel:@"Push Settings"];
    [tester setOn:NO forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"];

    // save push disabled
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // verify push is disabled
    [tester verifyPushEnabled:NO];

    if ([UAPush shared].pushNotificationDelegate == pushDelegate) {
        [UAPush shared].pushNotificationDelegate = nil;
    }
    pushDelegate = nil;
}

- (void)testReceiveBroadcastPush {
    NSLog(@"-----------------------------------------------------------------------------------------------");
    NSLog(@"Test that a broadcast push is received and properly handled.");
    NSLog(@"-----------------------------------------------------------------------------------------------");

    // Now send a broadcast push and verify we received the notification
    [tester sendAndWaitForNotification:@"Send a broadcast Push" sendPushBlock:^(NSString *alertID) {
        [UAPushClient sendBroadcastAlert:alertID];
    }];
}

- (void)testReceiveUnicastPush {
    NSLog(@"-----------------------------------------------------------------------------------------------");
    NSLog(@"Test that a unicast push is received and properly handled.");
    NSLog(@"-----------------------------------------------------------------------------------------------");

    // Now send a unicast push to the device token and verify we received the notification
    [tester sendAndWaitForNotification:@"Send a unicast Push" sendPushBlock:^(NSString *alertID) {
        [UAPushClient sendAlert:alertID toDeviceToken:[UAPush shared].deviceToken];
    }];
}

- (void)testSetAlias {
    NSLog(@"-----------------------------------------------------------------------------------------------");
    NSLog(@"Test that an alias can be set and we can receive a push");
    NSLog(@"-----------------------------------------------------------------------------------------------");

    NSString *uniqueAlias = [[UAUtils UUID] lowercaseString];

    [tester tapViewWithAccessibilityLabel:@"Token Settings"];
    [tester tapViewWithAccessibilityLabel:@"Alias"];

    // edit the alias with the uniqueAlias
    [tester enterText:uniqueAlias intoViewWithAccessibilityLabel:@"Edit Alias"];

    // save the alias and go back
    [tester tapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton];
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    NSLog(@"Wait for the registration to succeed.");
    [tester waitForTimeInterval:kAliasTagsRegistrationWait];

    // Now send a push to the alias and verify we received the notification
    [tester sendAndWaitForNotification:@"Send Push to alias" sendPushBlock:^(NSString *alertID) {
        [UAPushClient sendAlert:alertID toAlias:uniqueAlias];
    }];

}

- (void)testSetTag {
    NSLog(@"-----------------------------------------------------------------------------------------------");
    NSLog(@"Test that a tag can be set.");
    NSLog(@"-----------------------------------------------------------------------------------------------");

    NSString *uniqueTag = [[UAUtils UUID] lowercaseString];

    [tester tapViewWithAccessibilityLabel:@"Token Settings"];
    [tester tapViewWithAccessibilityLabel:@"Tags"];

    // delete any existing tags
    for (NSString *tag in [UAPush shared].tags) {
        [tester tapViewWithAccessibilityLabel:[NSString stringWithFormat:@"Delete %@", tag] traits:UIAccessibilityTraitButton];

        // iOS 7 UI requires another tap on 'Delete' button, while older versions need to confirm deletion.
        IF_IOS7_OR_GREATER([tester tapViewWithAccessibilityLabel:[NSString stringWithFormat:@"Delete"] traits:UIAccessibilityTraitButton];)
        else {
            [tester tapViewWithAccessibilityLabel:[NSString stringWithFormat:@"Confirm Deletion for %@", tag] traits:UIAccessibilityTraitButton];
        }
    }

    // add a tag with the uniqueTag
    [tester tapViewWithAccessibilityLabel:@"Add" traits:UIAccessibilityTraitButton];
    [tester enterText:uniqueTag intoViewWithAccessibilityLabel:@"Custom Tag Input"];

    // save the tag
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // back to token screen
    [tester tapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton];

    // back to main screen
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // wait for registration
    NSLog(@"Wait for the registration to succeed.");
    [tester waitForTimeInterval:kAliasTagsRegistrationWait];

    // Now send a push to the tag and verify we received the notification
    [tester sendAndWaitForNotification:@"Send Push to tag" sendPushBlock:^(NSString *alertID) {
        [UAPushClient sendAlert:alertID toTag:uniqueTag];
    }];
}

@end

