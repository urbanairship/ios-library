/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAAddCustomEventActionTest : UABaseTest
@property(nonatomic, strong) UATestAnalytics *analytics;
@property(nonatomic, strong) UATestAirshipInstance *airship;
@property (nonatomic, strong) UAAddCustomEventAction *action;
@end

@implementation UAAddCustomEventActionTest

- (void)setUp {
    [super setUp];

    self.analytics = [[UATestAnalytics alloc] init];
    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.analytics];
    [self.airship makeShared];
    self.action = [[UAAddCustomEventAction alloc] init];
}

/**
 * Test custom event action accepts all the situations.
 */
- (void)testAcceptsArgumentsAllSituations {
    NSDictionary *dict = @{@"event_name":@"event name"};

    [self verifyAcceptsArgumentsWithValue:dict shouldAccept:YES];
}

/**
 * Test that it rejects invalid argument values.
 */
- (void)testAcceptsArgumentsNo {
    NSDictionary *invalidDict = @{@"invalid_key":@"event name"};
    [self verifyAcceptsArgumentsWithValue:invalidDict shouldAccept:NO];

    [self verifyAcceptsArgumentsWithValue:nil shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@"not a dictionary" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:[[NSObject alloc] init] shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:[[NSDictionary alloc] init] shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@[] shouldAccept:NO];
}

/**
 * Test performing the action actually creates and adds the event from a NSNumber event value.
 */
- (void)testPerformNSNumber {
    NSDictionary *dict = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction ID",
                           @"event_value": @(123.45),
                           @"interaction_type": @"interaction type",
                           @"interaction_id": @"interaction ID"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    XCTAssertEqual(1, self.analytics.events.count);
    UACustomEvent *event = self.analytics.events.firstObject;
    XCTAssertEqualObjects(@"event name", event.eventName);
    XCTAssertEqualObjects(@"transaction ID", event.transactionID);
    XCTAssertEqualObjects(@"interaction type", event.interactionType);
    XCTAssertEqualObjects(@"interaction ID", event.interactionID);
    XCTAssertEqualObjects(@(123.45), event.eventValue);
}

/**
 * Test performing the action actually creates and adds the event from a string
 * event value.
 */
- (void)testPerformString {
    NSDictionary *dict = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction ID",
                           @"event_value": @"123.45",
                           @"interaction_type": @"interaction type",
                           @"interaction_id": @"interaction ID"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    XCTAssertEqual(1, self.analytics.events.count);
    UACustomEvent *event = self.analytics.events.firstObject;
    XCTAssertEqualObjects(@"event name", event.eventName);
    XCTAssertEqualObjects(@"transaction ID", event.transactionID);
    XCTAssertEqualObjects(@"interaction type", event.interactionType);
    XCTAssertEqualObjects(@"interaction ID", event.interactionID);
    XCTAssertEqualObjects(@(123.45), event.eventValue);
}

/**
 * Test perform with invalid event name should result in error.
 */
- (void)testPerformInvalidCustomEventName {
    NSDictionary *dict = @{@"event_name": @"",
                           @"transaction_id": @"transaction ID",
                           @"event_value": @"123.45",
                           @"interaction_type": @"interaction type",
                           @"interaction_id": @"interaction ID"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict withSituation:UASituationManualInvocation];

    NSError *error = [UAirshipErrors error:@"Invalid custom event"];
    UAActionResult *expectedResult = [UAActionResult resultWithError:error];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];
}

/**
 * Test auto filling in the interaction ID and type from an mcrap when left
 * empty.
 */
- (void)testInteractionEmptyMCRAP {

    NSDictionary *eventPayload = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction ID",
                           @"event_value": @"123.45"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:eventPayload
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataInboxMessageIDKey: @"message ID"}];

    UAActionResult *expectedResult = [UAActionResult emptyResult];
    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    XCTAssertEqual(1, self.analytics.events.count);
    UACustomEvent *event = self.analytics.events.firstObject;
    XCTAssertEqualObjects(@"event name", event.eventName);
    XCTAssertEqualObjects(@"transaction ID", event.transactionID);
    XCTAssertEqualObjects(@"ua_mcrap", event.interactionType);
    XCTAssertEqualObjects(@"message ID", event.interactionID);
    XCTAssertEqualObjects(@(123.45), event.eventValue);
}

/**
 * Test not modifying the interaction ID and type when it is set and triggered
 * from an mcrap.
 */
- (void)testInteractionSetMCRAP {
    NSDictionary *eventPayload = @{@"event_name": @"event name",
                                   @"transaction_id": @"transaction ID",
                                   @"event_value": @"123.45",
                                   @"interaction_type": @"interaction type",
                                   @"interaction_id": @"interaction ID"};


    UAActionArguments *args = [UAActionArguments argumentsWithValue:eventPayload
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataInboxMessageIDKey: @"message ID"}];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    XCTAssertEqual(1, self.analytics.events.count);
    UACustomEvent *event = self.analytics.events.firstObject;
    XCTAssertEqualObjects(@"event name", event.eventName);
    XCTAssertEqualObjects(@"transaction ID", event.transactionID);
    XCTAssertEqualObjects(@"interaction type", event.interactionType);
    XCTAssertEqualObjects(@"interaction ID", event.interactionID);
    XCTAssertEqualObjects(@(123.45), event.eventValue);
}


/**
 * Test setting the conversion send ID on the event if the action arguments has
 * a push payload meta data.
 */
- (void)testSetConversionSendIdFromPush {
    NSDictionary *dict = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction ID",
                           @"event_value": @"123.45",
                           @"interaction_type": @"interaction type",
                           @"interaction_id": @"interaction ID"};

    NSDictionary *notification = @{ @"_": @"send ID",
                                    @"com.urbanairship.metadata": @"send metadata",
                                    @"apns": @{@"alert": @"oh hi"} };

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataPushPayloadKey:notification}];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    XCTAssertEqual(1, self.analytics.events.count);
    UACustomEvent *event = self.analytics.events.firstObject;
    XCTAssertEqualObjects(@"event name", event.eventName);
    XCTAssertEqualObjects(@"transaction ID", event.transactionID);
    XCTAssertEqualObjects(@"interaction type", event.interactionType);
    XCTAssertEqualObjects(@"interaction ID", event.interactionID);
    XCTAssertEqualObjects(@"send ID", event.data[@"conversion_send_id"]);
    XCTAssertEqualObjects(@"send metadata", event.data[@"conversion_metadata"]);
    XCTAssertEqualObjects(@(123.45), event.eventValue);
}


/**
 * Test settings properties on a custom event.
 */
- (void)testSetCustomProperties {
    NSDictionary *dict = @{ @"event_name": @"event name",
                            @"properties": @{
                                    @"array": @[@"string", @"another string"],
                                    @"bool": @YES,
                                    @"number": @123,
                                    @"string": @"string value" } };


    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation];

    UAActionResult *expectedResult = [UAActionResult emptyResult];
    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    XCTAssertEqual(1, self.analytics.events.count);
    UACustomEvent *event = self.analytics.events.firstObject;
    XCTAssertEqualObjects(@"event name", event.eventName);
    XCTAssertEqualObjects(dict[@"properties"], event.properties);
}

/**
 * Helper method to verify perform.
 */
- (void)verifyPerformWithArgs:(UAActionArguments *)args
           withExpectedResult:(UAActionResult *)expectedResult {
    
    XCTestExpectation *finished = [self expectationWithDescription:@"Fetched frequency checker"];
    
    [self.action performWithArguments:args completionHandler:^(UAActionResult *result) {
        [finished fulfill];
        XCTAssertEqual(result.status, expectedResult.status, @"Result status should match expected result status.");
        XCTAssertEqual(result.fetchResult, expectedResult.fetchResult, @"FetchResult should match expected fetchresult.");
    }];
    
    [self waitForTestExpectations];
}

/**
 * Helper method to verify perform.
 */
- (void)verifyPerformWithArgs:(UAActionArguments *)args
                   actionName:(NSString *)actionName
           withExpectedResult:(UAActionResult *)expectedResult {

    XCTestExpectation *finished = [self expectationWithDescription:@"Finished"];

    [self.action performWithArguments:args completionHandler:^(UAActionResult *result) {
        [finished fulfill];
        XCTAssertEqual(result.status, expectedResult.status, @"Result status should match expected result status.");
        XCTAssertEqual(result.fetchResult, expectedResult.fetchResult, @"FetchResult should match expected fetchresult.");
    }];

    [self waitForTestExpectations];
}

/**
 * Helper method to verify accepts arguments.
 */
- (void)verifyAcceptsArgumentsWithValue:(id)value shouldAccept:(BOOL)shouldAccept {
    NSArray *situations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                            [NSNumber numberWithInteger:UASituationForegroundPush],
                            [NSNumber numberWithInteger:UASituationBackgroundPush],
                            [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                            [NSNumber numberWithInteger:UASituationManualInvocation],
                            [NSNumber numberWithInteger:UASituationForegroundInteractiveButton],
                            [NSNumber numberWithInteger:UASituationBackgroundInteractiveButton],
                            [NSNumber numberWithInteger:UASituationAutomation]];

    for (NSNumber *situationNumber in situations) {
        UAActionArguments *args = [UAActionArguments argumentsWithValue:value
                                                          withSituation:[situationNumber integerValue]];

        BOOL accepts = [self.action acceptsArguments:args];
        if (shouldAccept) {
            XCTAssertTrue(accepts, @"Add custom event action should accept value %@ in situation %@", value, situationNumber);
        } else {
            XCTAssertFalse(accepts, @"Add custom event action should not accept value %@ in situation %@", value, situationNumber);
        }
    }
}



@end
