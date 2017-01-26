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
#import "UAanalytics.h"
#import "UAirship.h"
#import "UAAddCustomEventAction.h"
#import "UAAction+Internal.h"
#import "UACustomEvent.h"
#import "UAInboxMessage.h"

@interface UAAddCustomEventActionTest : XCTestCase

@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@property (nonatomic, strong) UAAddCustomEventAction *action;
@end

@implementation UAAddCustomEventActionTest

- (void)setUp {
    self.analytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.airship = [OCMockObject mockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];

    self.action = [[UAAddCustomEventAction alloc] init];

    [super setUp];
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];
    [super tearDown];
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

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
               [event.transactionID isEqualToString:@"transaction ID"] &&
               [event.eventValue isEqualToNumber:@(123.45)] &&
               [event.interactionType isEqualToString:@"interaction type"] &&
               [event.interactionID isEqualToString:@"interaction ID"];

    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
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

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.transactionID isEqualToString:@"transaction ID"] &&
        [event.eventValue isEqualToNumber:@(123.45)] &&
        [event.interactionType isEqualToString:@"interaction type"] &&
        [event.interactionID isEqualToString:@"interaction ID"];

    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
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

    NSError *error = [NSError errorWithDomain:UAAddCustomEventActionErrorDomain
                                         code:UAAddCustomEventActionErrorCodeInvalidEventName
                                     userInfo:@{NSLocalizedDescriptionKey:@"Invalid event. Verify event name is not empty and within 255 characters."}];
    
    UAActionResult *expectedResult = [UAActionResult resultWithError:error];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];
}


/**
 * Test auto filling in the interaction ID and type from an mcrap when left
 * empty.
 */
- (void)testInteractionEmptyMCRAP {
    id message = [OCMockObject mockForClass:[UAInboxMessage class]];
    [[[message stub] andReturn:@"message ID"] messageID];
    [[[message stub] andReturn:@"messageTitle"] title];
    [[[message stub] andReturn:@"someContentType"] contentType];
    [[[message stub] andReturn:@{@"someKey":@"someValue"}] extra];
    [[[message stub] andReturn:@"http://someMessageBodyUrl"] messageBodyURL];
    [[[message stub] andReturn:@"http://someMessageUrl"] messageURL];
    [[[message stub] andReturn:@NO] unread];
    [[[message stub] andReturn:[NSDate dateWithTimeIntervalSince1970:1376352982]] messageSent];

    NSDictionary *eventPayload = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction ID",
                           @"event_value": @"123.45"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:eventPayload
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataInboxMessageKey: message}];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.transactionID isEqualToString:@"transaction ID"] &&
        [event.eventValue isEqualToNumber:@(123.45)] &&
        [event.interactionID isEqualToString:@"message ID"] &&
        [event.interactionType isEqualToString:@"ua_mcrap"];
    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
}

/**
 * Test not modifying the interaction ID and type when it is set and triggered
 * from an mcrap.
 */
- (void)testInteractionSetMCRAP {
    id message = [OCMockObject mockForClass:[UAInboxMessage class]];
    [[[message stub] andReturn:@"message ID"] messageID];
    [[[message stub] andReturn:@"messageTitle"] title];
    [[[message stub] andReturn:@"someContentType"] contentType];
    [[[message stub] andReturn:@{@"someKey":@"someValue"}] extra];
    [[[message stub] andReturn:@"http://someMessageBodyUrl"] messageBodyURL];
    [[[message stub] andReturn:@"http://someMessageUrl"] messageURL];
    [[[message stub] andReturn:@NO] unread];
    [[[message stub] andReturn:[NSDate dateWithTimeIntervalSince1970:1376352982]] messageSent];
    
    NSDictionary *eventPayload = @{@"event_name": @"event name",
                                   @"transaction_id": @"transaction ID",
                                   @"event_value": @"123.45",
                                   @"interaction_type": @"interaction type",
                                   @"interaction_id": @"interaction ID"};


    UAActionArguments *args = [UAActionArguments argumentsWithValue:eventPayload
                                                      withSituation:UASituationManualInvocation
                                                           metadata:@{UAActionMetadataInboxMessageKey: message}];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.transactionID isEqualToString:@"transaction ID"] &&
        [event.eventValue isEqualToNumber:@(123.45)] &&
        [event.interactionID isEqualToString:@"interaction ID"] &&
        [event.interactionType isEqualToString:@"interaction type"];
    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
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

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.transactionID isEqualToString:@"transaction ID"] &&
        [event.eventValue isEqualToNumber:@(123.45)] &&
        [event.interactionType isEqualToString:@"interaction type"] &&
        [event.interactionID isEqualToString:@"interaction ID"] &&
        [event.data[@"conversion_send_id"] isEqualToString:@"send ID"] &&
        [event.data[@"conversion_metadata"] isEqualToString:@"send metadata"];
    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
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

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.data[@"properties"][@"bool"] isEqualToString:@"true"] &&
        [event.data[@"properties"][@"number"] isEqualToString:@"123"] &&
        [event.data[@"properties"][@"array"] isEqualToArray:dict[@"properties"][@"array"]] &&
        [event.data[@"properties"][@"string"] isEqualToString:@"\"string value\""];
    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
}


/**
 * Helper method to verify perform.
 */
- (void)verifyPerformWithArgs:(UAActionArguments *)args
           withExpectedResult:(UAActionResult *)expectedResult {

    __block BOOL finished = NO;

    [self.action performWithArguments:args completionHandler:^(UAActionResult *result) {
        finished = YES;
        XCTAssertEqual(result.status, expectedResult.status, @"Result status should match expected result status.");
        XCTAssertEqual(result.fetchResult, expectedResult.fetchResult, @"FetchResult should match expected fetchresult.");
    }];

    XCTAssertTrue(finished, @"Action should have completed.");
}

/**
 * Helper method to verify perform.
 */
- (void)verifyPerformWithArgs:(UAActionArguments *)args
                   actionName:(NSString *)actionName
           withExpectedResult:(UAActionResult *)expectedResult {
    
    __block BOOL finished = NO;
    
    [self.action performWithArguments:args completionHandler:^(UAActionResult *result) {
        finished = YES;
        XCTAssertEqual(result.status, expectedResult.status, @"Result status should match expected result status.");
        XCTAssertEqual(result.fetchResult, expectedResult.fetchResult, @"FetchResult should match expected fetchresult.");
    }];
    
    XCTAssertTrue(finished, @"Action should have completed.");
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
