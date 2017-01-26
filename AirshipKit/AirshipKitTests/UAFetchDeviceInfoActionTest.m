/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.
 
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


#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAFetchDeviceInfoAction.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UANamedUser.h"
#import "UAActionArguments+Internal.h"

@interface UAFetchDeviceInfoActionTest : XCTestCase

@property(nonatomic, strong) UAFetchDeviceInfoAction *action;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockNamedUser;

@end

@implementation UAFetchDeviceInfoActionTest

- (void)setUp {
    [super setUp];
    
    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];
    self.mockNamedUser = [OCMockObject niceMockForClass:[UANamedUser class]];
    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];
    [[[self.mockAirship stub] andReturn:self.mockNamedUser] namedUser];

    self.action = [[UAFetchDeviceInfoAction alloc] init];
}

- (void)tearDown {
    [self.mockPush stopMocking];
    [self.mockNamedUser stopMocking];
    [self.mockAirship stopMocking];
    [super tearDown];
}

/**
 * Test accepts arguments.
 */
- (void)testAcceptsArguments {
    UASituation validSituations[8] = {
        UASituationLaunchedFromPush,
        UASituationForegroundPush,
        UASituationBackgroundPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationAutomation,
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton
    };
    
    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationBackgroundInteractiveButton;
    
    for (int i = 0; i < 8; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }
}

- (void)testPerformWithTags {
    NSString *channelID = @"channel_id";
    NSString *namedUserID = @"named_user";
    NSArray *tags = @[@"tag1", @"tag2", @"tag3"];
    UANotificationOptions expectedOptions = 1;
    
    [[[self.mockPush stub] andReturn:channelID] channelID];
    [(UAPush *)[[self.mockPush stub] andReturn:tags] tags];
    [(UAPush *)[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(expectedOptions)] authorizedNotificationOptions];
    [(UANamedUser *)[[self.mockNamedUser stub] andReturn:namedUserID] identifier];
    
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationWebViewInvocation;
    
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqualObjects(channelID, result.value[@"channel_id"]);
        XCTAssertEqualObjects(namedUserID, result.value[@"named_user"]);
        XCTAssertTrue(result.value[@"push_opt_in"]);
        XCTAssertEqualObjects(tags, result.value[@"tags"]);
    }];

    XCTAssertTrue(actionPerformed);
}

- (void)testPerformWithoutTags {
    NSString *channelID = @"channel_id";
    NSString *namedUserID = @"named_user";
    NSArray *tags = @[];
    UANotificationOptions expectedOptions = 1;
    
    [[[self.mockPush stub] andReturn:channelID] channelID];
    [(UAPush *)[[self.mockPush stub] andReturn:tags] tags];
    [(UAPush *)[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(expectedOptions)] authorizedNotificationOptions];
    [(UANamedUser *)[[self.mockNamedUser stub] andReturn:namedUserID] identifier];
    
    __block BOOL actionPerformed = NO;
    
    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationWebViewInvocation;
    
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqualObjects(channelID, result.value[@"channel_id"]);
        XCTAssertEqualObjects(namedUserID, result.value[@"named_user"]);
        XCTAssertTrue(result.value[@"push_opt_in"]);
        XCTAssertNil(result.value[@"tags"]);
    }];
    
    XCTAssertTrue(actionPerformed);
}

@end
