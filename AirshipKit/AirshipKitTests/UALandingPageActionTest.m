/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UALandingPageAction.h"
#import "UAAction+Internal.h"
#import "UAirship+Internal.h"
#import "UARuntimeConfig.h"
#import "UAUtils+Internal.h"
#import "NSString+UAURLEncoding.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAInAppMessageScheduleInfo+Internal.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAMessageCenter.h"

@interface UALandingPageActionTest : UABaseTest

@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockConfig;
@property (nonatomic, strong) UALandingPageAction *action;
@property (nonatomic, assign) id mockWhitelist;
@property (nonatomic, strong) id mockInAppMessageManager;


@end

@implementation UALandingPageActionTest

- (void)setUp {
    [super setUp];
    self.action = [[UALandingPageAction alloc] init];

    self.mockConfig = [self mockForClass:[UARuntimeConfig class]];
    self.mockAirship = [self mockForClass:[UAirship class]];
    self.mockWhitelist =  [self mockForClass:[UAWhitelist class]];

    [[[self.mockAirship stub] andReturn:self.mockConfig] config];
    [[[self.mockAirship stub] andReturn:self.mockWhitelist] whitelist];
    [UAirship setSharedAirship:self.mockAirship];

    [[[self.mockConfig stub] andReturn:@"app-key"] appKey];
    [[[self.mockConfig stub] andReturn:@"app-secret"] appSecret];

    // Set an actual whitelist
    UAWhitelist *whitelist = [UAWhitelist whitelistWithConfig:self.mockConfig];
    [[[self.mockAirship stub] andReturn:whitelist] whitelist];

    self.mockInAppMessageManager = [self mockForClass:[UAInAppMessageManager class]];
    [[[self.mockAirship stub] andReturn:self.mockConfig] config];
    [[[self.mockAirship stub] andReturn:self.mockInAppMessageManager] sharedInAppMessageManager];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockWhitelist stopMocking];
    [self.mockConfig stopMocking];
}

/**
 * Test accepts arguments
 */
- (void)testAcceptsArguments {
    [[[[self.mockWhitelist stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isWhitelisted:OCMOCK_ANY scope:UAWhitelistScopeOpenURL];

    [self verifyAcceptsArgumentsWithValue:@"foo.urbanairship.com" shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@"https://foo.urbanairship.com" shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@"http://foo.urbanairship.com" shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@"file://foo.urbanairship.com" shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:[NSURL URLWithString:@"https://foo.urbanairship.com"] shouldAccept:YES];
}

/**
 * Test accepts arguments rejects argument values that are unable to parsed
 * as a URL
 */
- (void)testAcceptsArgumentsNo {
    [[[[self.mockWhitelist stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isWhitelisted:OCMOCK_ANY scope:UAWhitelistScopeOpenURL];

    [self verifyAcceptsArgumentsWithValue:nil shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:[[NSObject alloc] init] shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@[] shouldAccept:NO];
}

/**
 * Test rejects arguments with URLs that are not whitelisted.
 */
- (void)testWhiteList {
    [[[[self.mockWhitelist stub] andReturnValue:OCMOCK_VALUE(NO)] ignoringNonObjectArgs] isWhitelisted:OCMOCK_ANY scope:UAWhitelistScopeOpenURL];

    [self verifyAcceptsArgumentsWithValue:@"foo.urbanairship.com" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@"https://foo.urbanairship.com" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@"http://foo.urbanairship.com" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@"file://foo.urbanairship.com" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:[NSURL URLWithString:@"https://foo.urbanairship.com"] shouldAccept:NO];
}

/**
 * Test perform in foreground situations
 */
- (void)testPerformInForeground {
    [[[[self.mockWhitelist stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isWhitelisted:OCMOCK_ANY scope:UAWhitelistScopeOpenURL];

    NSString *urlString = @"www.airship.com";
    // Expected URL String should be message ID with prepended message scheme.
    NSString *expectedURLString = [NSString stringWithFormat:@"%@%@", @"https://", urlString];
    [self verifyPerformWithArgValue:urlString expectedURLString:expectedURLString metadata:nil];
}

/**
 * Test perform with a message ID thats available in the message list is displayed
 * in a landing page controller.
 */
- (void)verifyPerformWithArgValue:(id)value expectedURLString:(NSString *)expectedURLString metadata:(NSDictionary * __nullable)metadata {
    __block BOOL actionPerformed;

    UASituation validSituations[6] = {
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationForegroundPush,
        UASituationAutomation
    };

    for (int i = 0; i < 6; i++) {
        UAActionArguments *arguments;

        if (metadata) {
            arguments = [UAActionArguments argumentsWithValue:value withSituation:validSituations[i] metadata:metadata];
        } else {
            arguments = [UAActionArguments argumentsWithValue:value withSituation:validSituations[i]];
        }

        [[[self.mockInAppMessageManager expect] andDo:^(NSInvocation *invocation) {
            void *scheduleInfoArg;
            [invocation getArgument:&scheduleInfoArg atIndex:2];
            UAInAppMessageScheduleInfo *scheduleInfo = (__bridge UAInAppMessageScheduleInfo *)scheduleInfoArg;

            UAInAppMessage *message = scheduleInfo.message;

            XCTAssertEqual(message.displayType, UAInAppMessageDisplayTypeHTML);
            XCTAssertEqualObjects(message.displayBehavior, UAInAppMessageDisplayBehaviorImmediate);
            XCTAssertEqual(message.isReportingEnabled, NO);

            UAInAppMessageHTMLDisplayContent *displayContent = (UAInAppMessageHTMLDisplayContent *)message.displayContent;
            XCTAssertEqual(displayContent.requireConnectivity, NO);
            XCTAssertEqualObjects(displayContent.url, expectedURLString);

            void *handlerArg;
            [invocation getArgument:&handlerArg atIndex:3];
            void (^handler)(UASchedule *) = (__bridge void (^)(UASchedule *))handlerArg;
            handler(nil);

        }] scheduleMessageWithScheduleInfo:OCMOCK_ANY completionHandler:OCMOCK_ANY];

        [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
            actionPerformed = YES;
            XCTAssertNil(result.value);
            XCTAssertNil(result.error);
        }];

        XCTAssertTrue(actionPerformed);
        [self.mockInAppMessageManager verify];
    }
}

/**
 * Helper method to verify accepts arguments
 */
- (void)verifyAcceptsArgumentsWithValue:(id)value shouldAccept:(BOOL)shouldAccept {
    NSArray *situations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                                     [NSNumber numberWithInteger:UASituationForegroundPush],
                                     [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                                     [NSNumber numberWithInteger:UASituationManualInvocation]];

    for (NSNumber *situationNumber in situations) {
        UAActionArguments *args = [UAActionArguments argumentsWithValue:value
                                                          withSituation:[situationNumber integerValue]];

        BOOL accepts = [self.action acceptsArguments:args];
        if (shouldAccept) {
            XCTAssertTrue(accepts, @"landing page action should accept value %@ in situation %@", value, situationNumber);
        } else {
            XCTAssertFalse(accepts, @"landing page action should not accept value %@ in situation %@", value, situationNumber);
        }
    }
}

@end
