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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAInAppMessage.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UAInAppMessageTest : XCTestCase
@property(nonatomic, strong) id mockAirship;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) NSDictionary *payload;
@end

@implementation UAInAppMessageTest

- (void)setUp {
    [super setUp];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    self.dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"test"];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.dataStore] dataStore];

    id expiry = @"2020-12-15T11:45:22";
    id extra = @{@"foo":@"bar", @"baz":@12345};

    id display = @{@"alert":@"hi!", @"type":@"banner", @"duration":@20, @"position":@"top", @"primary_color":@"#ffffffff", @"secondary_color":@"#ff00ff00"};

    id actions = @{@"on_click":@{@"^d":@"http://google.com"}, @"button_group":@"ua_yes_no_foreground", @"button_actions":@{@"yes":@{@"^+t": @"yes_tag"}, @"no":@{@"^+t": @"no_tag"}}};

    self.payload = @{@"identifier":@"some identifier", @"expiry":expiry, @"extra":extra, @"display":display, @"actions":actions};
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [super tearDown];
}

/**
 * Helper method for verifying model/payload equivalence 
 */
- (void)verifyPayloadConsistency:(UAInAppMessage *)message {

    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSGregorianCalendar];
    gregorian.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

    NSDateComponents *expiryComponents =
    [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:message.expiry];

    XCTAssertEqualObjects(message.identifier, @"some identifier");

    XCTAssertEqual(expiryComponents.year, 2020);
    XCTAssertEqual(expiryComponents.month, 12);
    XCTAssertEqual(expiryComponents.day, 15);
    XCTAssertEqual(expiryComponents.hour, 11);
    XCTAssertEqual(expiryComponents.minute, 45);
    XCTAssertEqual(expiryComponents.second, 22);

    XCTAssertEqualObjects(message.extra[@"foo"], self.payload[@"extra"][@"foo"]);
    XCTAssertEqualObjects(message.extra[@"baz"], self.payload[@"extra"][@"baz"]);

    XCTAssertEqualObjects(message.alert, self.payload[@"display"][@"alert"]);
    XCTAssertEqual(message.duration, [self.payload[@"display"][@"duration"] doubleValue]);
    XCTAssertEqual(message.position, UAInAppMessagePositionTop);
    XCTAssertEqual(message.displayType, UAInAppMessageDisplayTypeBanner);

    XCTAssertEqualObjects(message.buttonGroup, self.payload[@"actions"][@"button_group"]);
    XCTAssertEqualObjects(message.onClick, self.payload[@"actions"][@"on_click"]);
    XCTAssertEqualObjects(message.buttonActions, self.payload[@"actions"][@"button_actions"]);

    XCTAssertEqualObjects(message.primaryColor, [UIColor colorWithRed:1 green:1 blue:1 alpha:1]);
    XCTAssertEqualObjects(message.secondaryColor, [UIColor greenColor]);

    XCTAssertEqualObjects(message.payload, self.payload);
}

- (void)testDefaults {
    UAInAppMessage *message = [UAInAppMessage message];
    XCTAssertEqual(message.displayType, UAInAppMessageDisplayTypeBanner);
    XCTAssertEqual(message.position, UAInAppMessagePositionBottom);

    NSDate *expiry = message.expiry;
    NSDate *expectedExpiry = [NSDate dateWithTimeIntervalSinceNow:60 * 60 * 24 * 30];
    XCTAssertEqualWithAccuracy(expiry.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, 1);
}

/**
 * Test that payloads get turned into model objects properly
 */
- (void)testMessageWithPayload {
    UAInAppMessage *iam = [UAInAppMessage messageWithPayload:self.payload];
    [self verifyPayloadConsistency:iam];
}


/**
 * Test that messages can be compared for equality by value
 */
- (void)testIsEqualToMessage {
    UAInAppMessage *iam = [UAInAppMessage messageWithPayload:self.payload];
    UAInAppMessage *iam2 = [UAInAppMessage messageWithPayload:self.payload];
    XCTAssertTrue([iam isEqualToMessage:iam2]);

    iam.alert = @"sike!";

    XCTAssertFalse([iam isEqualToMessage:iam2]);
}

- (void)testUnexpectedDisplayAndPosition {
    NSMutableDictionary *weirdPayload = [NSMutableDictionary dictionaryWithDictionary:self.payload];
    NSDictionary *weirdDisplay = @{@"alert":@"yo!", @"type":@"not a type", @"position":@"sideways, starring paul giamatti"};

    weirdPayload[@"display"] = weirdDisplay;
    UAInAppMessage *iam = [UAInAppMessage messageWithPayload:weirdPayload];

    // default to unknown
    XCTAssertEqual(iam.displayType, UAInAppMessageDisplayTypeUnknown);

    // default to bottom
    XCTAssertEqual(iam.position, UAInAppMessagePositionBottom);
}

/**
 * Test that the payload parser drops values that don't conform to the expected type
 */
- (void)testSoftTypeChecking {
    NSMutableDictionary *weirdPayload = [NSMutableDictionary dictionaryWithDictionary:self.payload];
    NSDictionary *weirdDisplay = @{@"alert":@{@"not_a" : @"string"}, @"type":@24, @"duration":@"not a number", @"position":@[@1, @2, @3]};

    weirdPayload[@"display"] = weirdDisplay;

    UAInAppMessage *iam = [UAInAppMessage messageWithPayload:weirdPayload];

    // alert has no default, so it should be nil in this case
    XCTAssertNil(iam.alert);

    // default to unknown (as opposed to banner, which is the default when constructing a new object)
    XCTAssertEqual(iam.displayType, UAInAppMessageDisplayTypeUnknown);

    // default to bottom
    XCTAssertEqual(iam.position, UAInAppMessagePositionBottom);

    // default to 15 seconds
    XCTAssertEqual(iam.duration, 15);
}

@end
