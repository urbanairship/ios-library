/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAFetchDeviceInfoAction.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UANamedUser.h"
#import "UAActionArguments+Internal.h"

@interface UAFetchDeviceInfoActionTest : UABaseTest

@property(nonatomic, strong) UAFetchDeviceInfoAction *action;
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) id mockNamedUser;

@end

@implementation UAFetchDeviceInfoActionTest

- (void)setUp {
    [super setUp];
    
    self.mockPush = [self mockForClass:[UAPush class]];
    self.mockNamedUser = [self mockForClass:[UANamedUser class]];
    self.mockAirship = [self mockForClass:[UAirship class]];
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
    UAAuthorizedNotificationSettings expectedSettings = 1;
    
    [[[self.mockPush stub] andReturn:channelID] channelID];
    [(UAPush *)[[self.mockPush stub] andReturn:tags] tags];
    [(UAPush *)[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(expectedSettings)] authorizedNotificationSettings];
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
    UAAuthorizedNotificationSettings expectedSettings = 1;
    
    [[[self.mockPush stub] andReturn:channelID] channelID];
    [(UAPush *)[[self.mockPush stub] andReturn:tags] tags];
    [(UAPush *)[[self.mockPush stub] andReturnValue:OCMOCK_VALUE(expectedSettings)] authorizedNotificationSettings];
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
