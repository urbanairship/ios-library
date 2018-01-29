/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAActionArguments+Internal.h"
#import "UAChannelCaptureAction.h"
#import "UAChannelCapture.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UAChannelCaptureActionTest : UABaseTest

@property (nonatomic, strong) UAChannelCaptureAction *action;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAActionArguments *arguments;

@property(nonatomic, strong) id mockChannelCapture;
@property(nonatomic, strong) id airship;

@end

@implementation UAChannelCaptureActionTest

- (void)setUp {
    [super setUp];
    
    self.action = [[UAChannelCaptureAction alloc] init];
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"test.channelCapture."];
    
    self.mockChannelCapture = [self mockForClass:[UAChannelCapture class]];
    self.airship = [self strictMockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.mockChannelCapture] channelCapture];
    [[[self.airship stub] andReturn:self.dataStore] dataStore];

}

- (void)tearDown {
    [self.mockChannelCapture stopMocking];
    [self.airship stopMocking];
    
    [self.dataStore removeAll];
    [super tearDown];
}

- (void)testAcceptsArguments {
    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    
    UASituation validSituations[2] = {
        UASituationManualInvocation,
        UASituationBackgroundPush
    };
    
    UASituation invalidSituations[6] = {
        UASituationForegroundPush,
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationWebViewInvocation,
        UASituationAutomation
    };
    
    // Test valid/invalid situations.
    arguments.value = @100;
    for (int i = 0; i < 2; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }
    
    for (int i = 0; i < 5; i++) {
        arguments.situation = invalidSituations[i];
        XCTAssertFalse([self.action acceptsArguments:arguments], @"action should not accept situation %zd", invalidSituations[i]);
    }
    
    // Should only accept integers.
    arguments.situation = UASituationManualInvocation;
    arguments.value = @"Invalid argument";
    XCTAssertFalse([self.action acceptsArguments:arguments], @"action should not accept string arguments");
}

- (void)testPerformWithArguments {
    __block BOOL actionPerformed = NO;
    
    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationBackgroundPush;
    arguments.value = @1000;

    // Test enable
    [[self.mockChannelCapture expect] enable:1000];
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];
    [self.mockChannelCapture verify];
    XCTAssertTrue(actionPerformed);
    
    // Test disable
    actionPerformed = NO;
    arguments.value = @-1000;
    [[self.mockChannelCapture expect] disable];
    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
    }];
    XCTAssertTrue(actionPerformed);
}

@end
