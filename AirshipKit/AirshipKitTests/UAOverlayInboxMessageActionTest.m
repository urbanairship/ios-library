/* Copyright Airship and Contributors */


#import "UABaseTest.h"
#import "UAOverlayInboxMessageAction.h"
#import "UAActionArguments+Internal.h"
#import "UAirship+Internal.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UARuntimeConfig.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAInAppMessageScheduleInfo+Internal.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAMessageCenter.h"

@interface UAOverlayInboxMessageActionTest : UABaseTest

@property (nonatomic, strong) UAOverlayInboxMessageAction *action;
@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) id mockInbox;
@property (nonatomic, strong) id mockMessageList;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockInAppMessageManager;
@property (nonatomic, strong) id mockConfig;

@end

@implementation UAOverlayInboxMessageActionTest

- (void)setUp {
    [super setUp];

    self.action = [[UAOverlayInboxMessageAction alloc] init];

    self.mockAirship = [self strictMockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];

    self.mockInbox = [self strictMockForClass:[UAInbox class]];
    [[[self.mockAirship stub] andReturn:self.mockInbox] inbox];

    self.mockMessageList = [self mockForClass:[UAInboxMessageList class]];
    [[[self.mockInbox stub] andReturn:self.mockMessageList] messageList];

    // Set an actual whitelist
    UAWhitelist *whitelist = [UAWhitelist whitelistWithConfig:self.config];
    [[[self.mockAirship stub] andReturn:whitelist] whitelist];

    self.mockConfig = [self mockForClass:[UARuntimeConfig class]];
    self.mockInAppMessageManager = [self mockForClass:[UAInAppMessageManager class]];
    [[[self.mockAirship stub] andReturn:self.mockConfig] config];
    [[[self.mockAirship stub] andReturn:self.mockInAppMessageManager] sharedInAppMessageManager];
}


/**
 * Test the action accepts message ID in foreground situations.
 */
- (void)testAcceptsArgumentsMessageID {
    UASituation validSituations[6] = {
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationForegroundPush,
        UASituationAutomation
    };

    UASituation rejectedSituations[2] = {
        UASituationBackgroundPush,
        UASituationBackgroundInteractiveButton,
    };

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = @"the_message_id";

    for (int i = 0; i < 6; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    for (int i = 0; i < 2; i++) {
        arguments.situation = rejectedSituations[i];
        XCTAssertFalse([self.action acceptsArguments:arguments], @"action should reject situation %zd", rejectedSituations[i]);
    }
}

/**
 * Test the action accepts "auto" placeholder when it contains either inbox
 * message metadata or push notification metadata.
 */
- (void)testAcceptsArgumentMessageIDPlaceHolder {
    UASituation validSituations[6] = {
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationForegroundPush,
        UASituationAutomation
    };

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.value = @"auto";

    // Verify it rejects the valid situations if no metadata is present
    for (int i = 0; i < 6; i++) {
        arguments.situation = validSituations[i];
        XCTAssertFalse([self.action acceptsArguments:arguments], @"action should reject situation %zd", validSituations[i]);
    }

    // Verify it accepts the message place holder if we have a inbox message metadata
    arguments.metadata = @{UAActionMetadataInboxMessageKey: [self mockForClass:[UAInboxMessage class]]};
    for (int i = 0; i < 2; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    // Verify it accepts the message place holder if we have a push message metadata
    arguments.metadata = @{UAActionMetadataPushPayloadKey: @{}};
    for (int i = 0; i < 2; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }
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

- (void)testPerform {
    NSString *expectedMessageID = @"MCRAP";
    // Expected URL String should be message ID with prepended message scheme.
    NSString *expectedURLString = [NSString stringWithFormat:@"%@:%@", UAMessageDataScheme, expectedMessageID];
    id mockMessage = [self mockForClass:[UAInboxMessage class]];
    [[[mockMessage stub] andReturn:expectedMessageID] messageID];
    [[[self.mockMessageList stub] andReturn:mockMessage] messageForID:expectedMessageID];

    [self verifyPerformWithArgValue:expectedMessageID expectedURLString:expectedURLString metadata:nil];
}

/**
 * Test the action looks up the message in the inbox message metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerformWithPlaceHolderInboxMessageMetadata {
    NSString *expectedMessageID = @"MCRAP";
    // Expected URL String should be message ID with prepended message scheme.
    NSString *expectedURLString = [NSString stringWithFormat:@"%@:%@", UAMessageDataScheme, expectedMessageID];
    id mockMessage = [self mockForClass:[UAInboxMessage class]];
    [[[mockMessage stub] andReturn:expectedMessageID] messageID];
    [[[self.mockMessageList stub] andReturn:mockMessage] messageForID:expectedMessageID];

    [self verifyPerformWithArgValue:@"auto" expectedURLString:expectedURLString metadata:@{UAActionMetadataInboxMessageKey:(UAInboxMessage *)mockMessage}];
}

/**
 * Test the action looks up the message ID in the push notification metadata if the placeholder
 * is set for the arguments value.
 */
- (void)testPerformWithPlaceHolderPushMessageMetadata {
    NSString *expectedMessageID = @"MCRAP";
    // Expected URL String should be message ID with prepended message scheme.
    NSString *expectedURLString = [NSString stringWithFormat:@"%@:%@", UAMessageDataScheme, expectedMessageID];
    id mockMessage = [self mockForClass:[UAInboxMessage class]];
    [[[mockMessage stub] andReturn:expectedMessageID] messageID];
    [[[self.mockMessageList stub] andReturn:mockMessage] messageForID:expectedMessageID];

    NSDictionary *notification = @{@"_uamid": @"MCRAP"};

    [self verifyPerformWithArgValue:@"auto" expectedURLString:expectedURLString metadata:@{UAActionMetadataPushPayloadKey:notification}];
}

@end
