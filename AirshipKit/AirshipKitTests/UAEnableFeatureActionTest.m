/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

#import "UABaseTest.h"
#import <OCMock/OCMock.h>

#import "UAActionArguments+Internal.h"
#import "UAEnableFeatureAction.h"
#import "UAirship+Internal.h"
#import "UAPush.h"
#import "UALocation.h"

@interface UAEnableFeatureActionTest : UABaseTest

@property (nonatomic, strong) UAEnableFeatureAction *action;
@property (nonatomic, strong) UAActionArguments *arguments;

@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockLocation;
@property(nonatomic, strong) id mockAirship;

@end

@implementation UAEnableFeatureActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UAEnableFeatureAction alloc] init];

    self.mockPush = [self strictMockForClass:[UAPush class]];
    self.mockLocation = [self strictMockForClass:[UALocation class]];
    self.mockAirship = [self strictMockForClass:[UAirship class]];

    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockPush] sharedPush];
    [[[self.mockAirship stub] andReturn:self.mockLocation] sharedLocation];
}

- (void)tearDown {
    [self.mockPush stopMocking];
    [self.mockLocation stopMocking];
    [self.mockAirship stopMocking];
    [UAirship setSharedAirship:nil];
    [super tearDown];
}

- (void)testAcceptsArguments {
    UAActionArguments *arguments = [[UAActionArguments alloc] init];

    UASituation validSituations[6] = {
        UASituationManualInvocation,
        UASituationForegroundPush,
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationWebViewInvocation,
        UASituationAutomation
    };

    UASituation invalidSituations[2] = {
        UASituationBackgroundInteractiveButton,
        UASituationBackgroundPush,
    };

    NSArray *validValues = @[UAEnableLocationActionValue, UAEnableUserNotificationsActionValue, UAEnableBackgroundLocationActionValue];

    for (id value in validValues) {
        arguments.value = value;


        for (int i = 0; i < 6; i++) {
            arguments.situation = validSituations[i];
            XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
        }

        for (int i = 0; i < 2; i++) {
            arguments.situation = invalidSituations[i];
            XCTAssertFalse([self.action acceptsArguments:arguments], @"action should not accept situation %zd", invalidSituations[i]);
        }
    }

    // Verify invalid value
    arguments.situation = UASituationManualInvocation;
    arguments.value = @"Invalid argument";
    XCTAssertFalse([self.action acceptsArguments:arguments], @"action should not accept invalid arguments");
}


- (void)testEnableUserNotifications {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableUserNotificationsActionValue;

    [[self.mockPush expect] setUserPushNotificationsEnabled:YES];
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockPush verify];
    XCTAssertTrue(actionPerformed);
}

- (void)testEnableLocation {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableLocationActionValue;

    [[self.mockLocation expect] setLocationUpdatesEnabled:YES];
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockLocation verify];
    XCTAssertTrue(actionPerformed);
}

- (void)testEnableBackgroundLocation {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = UAEnableBackgroundLocationActionValue;

    [[self.mockLocation expect] setLocationUpdatesEnabled:YES];
    [[self.mockLocation expect] setBackgroundLocationUpdatesAllowed:YES];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];

    [self.mockLocation verify];
    XCTAssertTrue(actionPerformed);
}

@end
