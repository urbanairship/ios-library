/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UALandingPageAction.h"
#import "UAInAppAutomation.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UASchedule+Internal.h"
#import "UAActionResult.h"
#import "UAActionArguments.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UALandingPageActionTest : UABaseTest

@property (nonatomic, strong) UATestAirshipInstance *airship;
@property (nonatomic, strong) id mockConfig;
@property (nonatomic, strong) UALandingPageAction *action;
@property (nonatomic, strong) UATestURLAllowList *URLAllowList;
@property (nonatomic, strong) id mockInAppAutomation;

@end

@implementation UALandingPageActionTest

- (void)setUp {
    [super setUp];
    self.action = [[UALandingPageAction alloc] init];

    self.mockConfig = [self mockForClass:[UARuntimeConfig class]];
    self.URLAllowList = [[UATestURLAllowList alloc] init];

    [[[self.mockConfig stub] andReturn:@"app-key"] appKey];
    [[[self.mockConfig stub] andReturn:@"app-secret"] appSecret];

    self.mockInAppAutomation = [self mockForClass:[UAInAppAutomation class]];
    [[[self.mockInAppAutomation stub] andReturn:self.mockInAppAutomation] shared];
    
    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.mockInAppAutomation];
    self.airship.config = self.mockConfig;
    self.airship.urlAllowList = self.URLAllowList;
    [self.airship makeShared];
}

/**
 * Test accepts arguments
 */
- (void)testAcceptsArguments {
    self.URLAllowList.isAllowedReturnValue = YES;

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
    self.URLAllowList.isAllowedReturnValue = YES;

    [self verifyAcceptsArgumentsWithValue:nil shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:[[NSObject alloc] init] shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@[] shouldAccept:NO];
}

/**
 * Test rejects arguments with URLs that are not allowed.
 */
- (void)testURLAllowList {
    self.URLAllowList.isAllowedReturnValue = NO;

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
    self.URLAllowList.isAllowedReturnValue = YES;

    NSString *urlString = @"www.airship.com";
    // Expected URL String should be message ID with prepended message scheme.
    NSString *expectedURLString = [NSString stringWithFormat:@"%@%@", @"https://", urlString];
    [self verifyPerformWithArgValue:urlString expectedURLString:expectedURLString metadata:nil];
}

/**
 * Test perform with a message ID thats available in the message list is displayed
 * in a landing page controller.
 */
- (void)verifyPerformWithArgValue:(id)value expectedURLString:(NSString *)expectedURLString metadata:(nullable NSDictionary *)metadata {
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

        [[[self.mockInAppAutomation expect] andDo:^(NSInvocation *invocation) {
            void *scheduleArg;
            [invocation getArgument:&scheduleArg atIndex:2];
            UASchedule *schedule = (__bridge UASchedule *)scheduleArg;
            UAInAppMessage *message = schedule.data;

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

        }] schedule:OCMOCK_ANY completionHandler:OCMOCK_ANY];

        [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
            actionPerformed = YES;
            XCTAssertNil(result.value);
            XCTAssertNil(result.error);
        }];

        XCTAssertTrue(actionPerformed);
        [self.mockInAppAutomation verify];
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
