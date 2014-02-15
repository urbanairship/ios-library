/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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

#import "ChannelRegistrationKIFTest.h"
#import "UA_Reachability.h"
#import "UAPush.h"
#import "UAPush+Internal.h"
#import "UAChannelRegistrationPayload+UAAdditions.h"
#import "JRSwizzle.h"

#define kPushRegistrationWait 10.0

@implementation ChannelRegistrationKIFTest

// TODO: Need to run each test in its own app bundle immediately after a brand new app install.

- (void)testCRA {
    NSLog(@"-----------------------------------------------------------------------------------------------");
    NSLog(@"Test Channel Registration.");
    NSLog(@"-----------------------------------------------------------------------------------------------");

    // Capture connection type using Reachability
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    if (netStatus == UA_NotReachable) {
        NSLog(@"The Internet connection appears to be offline. Abort KIF tests.");
        exit(EXIT_FAILURE);
    }

    UADeviceRegistrar *registrar = [[UADeviceRegistrar alloc] init];

    // Force channel registration (current default)
    registrar.isUsingChannelRegistration = YES;

    // Enable push via the UI
    [tester tapViewWithAccessibilityLabel:@"Push Settings"];
    [tester setOn:YES forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"];
    [tester waitForViewWithAccessibilityLabel:@"Push Notifications Enabled" value:@"1" traits:UIAccessibilityTraitNone];

    // Save push enabled
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // Wait for registration
    NSLog(@"Wait for the registration to succeed.");
    [tester waitForTimeInterval:kPushRegistrationWait];

    // Verify device token
    [tester tapViewWithAccessibilityLabel:@"Token Settings"];
    [tester waitForTappableViewWithAccessibilityLabel:@"Device Token"];
    [tester tapViewWithAccessibilityLabel:@"Device Token"];
    [tester waitForViewWithAccessibilityLabel:[UAPush shared].deviceToken];
    [tester tapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton];

    // Verify channel ID created
    [tester tapViewWithAccessibilityLabel:@"Token Settings"];
    [tester waitForTappableViewWithAccessibilityLabel:@"Channel ID"];
    [tester tapViewWithAccessibilityLabel:@"Channel ID"];

    NSString *channelId = [UAPush shared].channelID;
    NSLog(@"      channel ID is: %@", channelId);
    [tester waitForViewWithAccessibilityLabel:channelId];
    [tester tapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton];
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // disable push via the UI
    [tester tapViewWithAccessibilityLabel:@"Push Settings"];
    [tester setOn:NO forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"];

    // save push disabled
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

}

- (void)testDRA {
    NSLog(@"-----------------------------------------------------------------------------------------------");
    NSLog(@"Test Device Registration.");
    NSLog(@"-----------------------------------------------------------------------------------------------");

    // Capture connection type using Reachability
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    if (netStatus == UA_NotReachable) {
        NSLog(@"The Internet connection appears to be offline. Abort KIF tests.");
        exit(EXIT_FAILURE);
    }

    UADeviceRegistrar *registrar = [[UADeviceRegistrar alloc] init];

    // Force device registration
    registrar.isUsingChannelRegistration = NO;

    [UAPush shared].deviceRegistrar = registrar;

    // Enable push via the UI
    [tester tapViewWithAccessibilityLabel:@"Push Settings"];
    [tester setOn:YES forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"];
    [tester waitForViewWithAccessibilityLabel:@"Push Notifications Enabled" value:@"1" traits:UIAccessibilityTraitNone];

    // Save push enabled
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // Wait for registration
    NSLog(@"Wait for the registration to succeed.");
    [tester waitForTimeInterval:kPushRegistrationWait];

    // Verify device token
    [tester tapViewWithAccessibilityLabel:@"Token Settings"];
    [tester waitForTappableViewWithAccessibilityLabel:@"Device Token"];
    [tester tapViewWithAccessibilityLabel:@"Device Token"];
    [tester waitForViewWithAccessibilityLabel:[UAPush shared].deviceToken];
    [tester tapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton];

    // Verify channel ID was not created (Should be Unavailable)
    [tester waitForTappableViewWithAccessibilityLabel:@"Channel ID"];
    [tester tapViewWithAccessibilityLabel:@"Channel ID"];
    [tester waitForViewWithAccessibilityLabel:@"Unavailable"];
    [tester tapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton];
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // disable push via the UI
    [tester tapViewWithAccessibilityLabel:@"Push Settings"];
    [tester setOn:NO forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"];

    // save push disabled
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];
}

- (void)testCRAfallbackToDRA {
    NSLog(@"-----------------------------------------------------------------------------------------------");
    NSLog(@"Test Channel Registration Fallback to Device Registration.");
    NSLog(@"-----------------------------------------------------------------------------------------------");

    // Capture connection type using Reachability
    NetworkStatus netStatus = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    if (netStatus == UA_NotReachable) {
        NSLog(@"The Internet connection appears to be offline. Abort KIF tests.");
        exit(EXIT_FAILURE);
    }

    // Swizzle to force server to return 501
    [UAChannelRegistrationPayload jr_swizzleMethod:@selector(asJSONData) withMethod:@selector(asJSONData_fallback) error:nil];

    UADeviceRegistrar *registrar = [[UADeviceRegistrar alloc] init];

    // Force channel registration (current default)
    registrar.isUsingChannelRegistration = YES;

    [UAPush shared].deviceRegistrar = registrar;

    // Enable push via the UI
    [tester tapViewWithAccessibilityLabel:@"Push Settings"];
    [tester setOn:YES forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"];
    [tester waitForViewWithAccessibilityLabel:@"Push Notifications Enabled" value:@"1" traits:UIAccessibilityTraitNone];

    // Save push enabled
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // Wait for registration
    NSLog(@"Wait for the registration to succeed.");
    [tester waitForTimeInterval:kPushRegistrationWait];

    // Verify device token
    [tester tapViewWithAccessibilityLabel:@"Token Settings"];
    [tester waitForTappableViewWithAccessibilityLabel:@"Device Token"];
    [tester tapViewWithAccessibilityLabel:@"Device Token"];
    [tester waitForViewWithAccessibilityLabel:[UAPush shared].deviceToken];
    [tester tapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton];

    // Verify channel ID was not created (Should be Unavailable)
    [tester waitForTappableViewWithAccessibilityLabel:@"Channel ID"];
    [tester tapViewWithAccessibilityLabel:@"Channel ID"];
    [tester waitForViewWithAccessibilityLabel:@"Unavailable"];
    [tester tapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton];
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // disable push via the UI
    [tester tapViewWithAccessibilityLabel:@"Push Settings"];
    [tester setOn:NO forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"];

    // save push disabled
    [tester tapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton];

    // Unswizzle
    [UAChannelRegistrationPayload jr_swizzleMethod:@selector(asJSONData_fallback) withMethod:@selector(asJSONData) error:nil];
}

@end
