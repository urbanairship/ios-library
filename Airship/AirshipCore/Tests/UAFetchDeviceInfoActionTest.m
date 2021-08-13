/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAirship+Internal.h"
#import "UAPush.h"
#import "UAChannel.h"
#import "UAActionArguments+Internal.h"
#import "UAActionResult.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAFetchDeviceInfoActionTest : UABaseTest

@property(nonatomic, strong) UAFetchDeviceInfoAction *action;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) UATestContact *testContact;

@end

@implementation UAFetchDeviceInfoActionTest

- (void)setUp {
    [super setUp];
    
    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.testContact = [[UATestContact alloc] init];
    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];
    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];
    [[[self.mockAirship stub] andReturn:self.testContact] contact];

    self.action = [[UAFetchDeviceInfoAction alloc] init];
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
    
    [[[self.mockChannel stub] andReturn:channelID] identifier];
    [(UAChannel *)[[self.mockChannel stub] andReturn:tags] tags];
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
    
    [[[self.mockChannel stub] andReturn:channelID] identifier];
    [(UAChannel *)[[self.mockChannel stub] andReturn:tags] tags];
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
