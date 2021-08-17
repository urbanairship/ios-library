/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAirship+Internal.h"
#import "UAPush.h"
#import "UAActionArguments+Internal.h"
#import "UAActionResult.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAFetchDeviceInfoActionTest : UABaseTest

@property(nonatomic, strong) UAFetchDeviceInfoAction *action;
@property(nonatomic, strong) id mockLocation;
@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) UATestChannel *testChannel;
@property(nonatomic, strong) UATestContact *testContact;

@end

@implementation UAFetchDeviceInfoActionTest

- (void)setUp {
    [super setUp];
    
    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockLocation = [self mockForProtocol:@protocol(UALocationProvider)];
    self.testChannel = [[UATestChannel alloc] init];
    self.testContact = [[UATestContact alloc] init];

    self.action = [[UAFetchDeviceInfoAction alloc] initWithChannel:^{ return self.testChannel; }
                                                           contact:^{ return self.testContact; }
                                                              push:^{ return self.mockPush; }
                                                          location:^{ return self.mockLocation; }];
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
    self.testContact.namedUserID = @"some user";
    NSArray *tags = @[@"tag1", @"tag2", @"tag3"];
    UAAuthorizedNotificationSettings expectedSettings = 1;
    
    self.testChannel.identifier = channelID;
    self.testChannel.tags = tags;
    [(UAPush *)[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(expectedSettings)] authorizedNotificationSettings];
    
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationWebViewInvocation;
    
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqualObjects(channelID, result.value[@"channel_id"]);
        XCTAssertEqualObjects(@"some user", result.value[@"named_user"]);
        XCTAssertTrue(result.value[@"push_opt_in"]);
        XCTAssertEqualObjects(tags, result.value[@"tags"]);
    }];

    XCTAssertTrue(actionPerformed);
}

- (void)testPerformWithoutTags {
    NSString *channelID = @"channel_id";
    self.testContact.namedUserID = @"some user";
    NSArray *tags = @[];
    UAAuthorizedNotificationSettings expectedSettings = 1;
    
    self.testChannel.identifier = channelID;
    self.testChannel.tags = tags;
    [(UAPush *)[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(expectedSettings)] authorizedNotificationSettings];
    
    __block BOOL actionPerformed = NO;
    
    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationWebViewInvocation;
    
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqualObjects(channelID, result.value[@"channel_id"]);
        XCTAssertEqualObjects(@"some user", result.value[@"named_user"]);
        XCTAssertTrue(result.value[@"push_opt_in"]);
        XCTAssertNil(result.value[@"tags"]);
    }];
    
    XCTAssertTrue(actionPerformed);
}

@end
