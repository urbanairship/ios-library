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
#import "UAChannelRegistrationPayload+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAPush+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"

@interface UAChannelRegistrationPayloadTest : XCTestCase
@property (nonatomic, strong) UAChannelRegistrationPayload *payload;
@end

@implementation UAChannelRegistrationPayloadTest

- (void)setUp {
    [super setUp];

    NSDictionary *quietTime = [self buildQuietTimeWithStartDate:[NSDate dateWithTimeIntervalSince1970:30]
                                                    withEndDate:[NSDate dateWithTimeIntervalSince1970:100]];

    self.payload = [[UAChannelRegistrationPayload alloc] init];

    // set up the full payload
    self.payload.optedIn = YES;
    self.payload.backgroundEnabled = YES;
    self.payload.pushAddress = @"FAKEADDRESS";
    self.payload.userID = @"fakeUser";
    self.payload.deviceID = @"fakeDeviceID";
    self.payload.badge = [NSNumber numberWithInteger:1];
    self.payload.quietTime =  quietTime;
    self.payload.timeZone = @"timezone";
    self.payload.alias = @"fakeAlias";
    self.payload.tags = @[@"tagOne", @"tagTwo"];
    self.payload.setTags = YES;
}

/**
 * Test that the json has the full expected payload
 */
- (void)testAsJsonFullPayload {
    NSString *jsonString = [[NSString alloc] initWithData:[self.payload asJSONData] encoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization objectWithString:jsonString];

    // identity hints
    NSDictionary *identityHints = [dict valueForKey:kUAChannelIdentityHintsKey];
    XCTAssertNotNil(identityHints, @"identity hints should be present");
    XCTAssertEqualObjects(self.payload.userID, [identityHints valueForKey:kUAChannelUserIDKey], @"user ID should be present");
    XCTAssertEqualObjects(self.payload.deviceID, [identityHints valueForKey:kUAChannelDeviceIDKey], @"device ID should be present");

    // channel specific items
    NSDictionary *channel = [dict valueForKey:kUAChannelKey];
    XCTAssertEqualObjects(@"ios", [channel valueForKey:kUAChannelDeviceTypeKey], @"device type should be present");
    XCTAssertEqualObjects([NSNumber numberWithBool:self.payload.optedIn], [channel valueForKey:kUAChannelOptInKey], @"opt-in should be present");
    XCTAssertEqualObjects([NSNumber numberWithBool:self.payload.backgroundEnabled], [channel valueForKey:kUABackgroundEnabledJSONKey], @"background should be present");
    XCTAssertEqualObjects(self.payload.pushAddress, [channel valueForKey:kUAChannelPushAddressKey], @"push address should be present");
    XCTAssertEqualObjects(self.payload.alias, [channel valueForKey:kUAChannelAliasJSONKey], @"alias should be present");
    XCTAssertEqualObjects([NSNumber numberWithBool:self.payload.setTags], [channel valueForKey:kUAChannelSetTagsKey], @"set tags should be present");
    XCTAssertEqualObjects(self.payload.tags, [channel valueForKey:kUAChannelTagsJSONKey], @"tags should be present");

    // iOS specific items
    NSDictionary *ios = [channel valueForKey:kUAChanneliOSKey];
    XCTAssertNotNil(ios, @"ios should be present");
    XCTAssertEqualObjects(self.payload.badge, [ios valueForKey:kUAChannelBadgeJSONKey], @"badge should be present");
    XCTAssertEqualObjects(self.payload.quietTime, [ios valueForKey:kUAChannelQuietTimeJSONKey], @"quiet time should be present");
    XCTAssertEqualObjects(self.payload.timeZone, [ios valueForKey:kUAChannelTimeZoneJSONKey], @"timezone should be present");
}

/**
 * Test when tags are empty or nil
 */
- (void)testAsJsonEmptyTags {
    self.payload.tags = nil;

    NSString *jsonString = [[NSString alloc] initWithData:[self.payload asJSONData] encoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization objectWithString:jsonString];
    NSDictionary *channel = [dict valueForKey:kUAChannelKey];
    XCTAssertNil([channel valueForKey:kUAChannelTagsJSONKey], @"tags should be nil");

    // Verify tags is not nil, but an empty nsarray
    self.payload.tags = @[];
    jsonString = [[NSString alloc] initWithData:[self.payload asJSONData] encoding:NSUTF8StringEncoding];
    dict = [NSJSONSerialization objectWithString:jsonString];
    channel = [dict valueForKey:kUAChannelKey];
    XCTAssertEqualObjects(self.payload.tags, [channel valueForKey:kUAChannelTagsJSONKey], @"tags should be nil");
}

/**
 * Test that tags are not sent when setTags is false
 */
- (void)testAsJsonNoTags {
    self.payload.setTags = NO;

    NSString *jsonString = [[NSString alloc] initWithData:[self.payload asJSONData] encoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization objectWithString:jsonString];
    NSDictionary *channel = [dict valueForKey:kUAChannelKey];

    // Verify that tags are not present when setTags is false
    jsonString = [[NSString alloc] initWithData:[self.payload asJSONData] encoding:NSUTF8StringEncoding];
    dict = [NSJSONSerialization objectWithString:jsonString];
    channel = [dict valueForKey:kUAChannelKey];
    XCTAssertNil([channel valueForKey:kUAChannelTagsJSONKey], @"tags should be nil");
}

/**
 * Test that an empty iOS section is not included
 */
- (void)testAsJsonEmptyiOSSection {
    self.payload.badge = nil;
    self.payload.quietTime = nil;
    self.payload.timeZone = nil;

    NSString *jsonString = [[NSString alloc] initWithData:[self.payload asJSONData] encoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization objectWithString:jsonString];

    XCTAssertNil([dict valueForKey:kUAChanneliOSKey], @"iOS section should not be included in the JSON");
}

/**
 * Test that an empty identity hints section is not included
 */
- (void)testAsJsonEmptyIdentityHints {
    self.payload.deviceID = nil;
    self.payload.userID = nil;

    NSString *jsonString = [[NSString alloc] initWithData:[self.payload asJSONData] encoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization objectWithString:jsonString];

    XCTAssertNil([dict valueForKey:kUAChannelIdentityHintsKey], @"identity hints section should not be included in the JSON");
}

/**
 * Test isEqualToPayload is equal to its copy
 */
- (void)testisEqualToPayloadCopy {
    UAChannelRegistrationPayload *payloadCopy = [self.payload copy];
    XCTAssertTrue([self.payload isEqualToPayload:payloadCopy], @"A copy should be equal to the original");

    payloadCopy.optedIn = NO;
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.optedIn = self.payload.optedIn;

    payloadCopy.backgroundEnabled = NO;
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.backgroundEnabled = self.payload.backgroundEnabled;

    payloadCopy.pushAddress = @"different-value";
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.pushAddress = self.payload.pushAddress;

    payloadCopy.userID = @"different-value";
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.userID = self.payload.userID;

    payloadCopy.deviceID = @"different-value";
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.deviceID = self.payload.deviceID;

    payloadCopy.badge = [NSNumber numberWithInteger:5];;
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.badge = self.payload.badge;

    payloadCopy.quietTime = [NSDictionary dictionary];
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.quietTime = self.payload.quietTime;

    payloadCopy.timeZone = @"different-value";
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.timeZone = self.payload.timeZone;

    payloadCopy.alias = @"different-value";
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.alias = self.payload.alias;

    payloadCopy.setTags = NO;
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.setTags = self.payload.setTags;

    payloadCopy.tags = @[@"tagThree", @"tagFour"];;
    XCTAssertFalse([self.payload isEqualToPayload:payloadCopy], @"A payload should not be equal after a modification");
    payloadCopy.tags = self.payload.tags;

    // Make sure its equal again
    XCTAssertTrue([self.payload isEqualToPayload:payloadCopy], @"A copy should be equal to the original");
}

/**
 * Test isEqualToPayload is equal to itself
 */
- (void)testisEqualToPayloadSelf {
    XCTAssertTrue([self.payload isEqualToPayload:self.payload], @"A payload should be equal to itself");
}

/**
 * Test isEqualToPayload is equal to an empty payload
 */
- (void)testisEqualToPayloadEmptyPayload {
    UAChannelRegistrationPayload *emptyPayload = [[UAChannelRegistrationPayload alloc] init];
    XCTAssertFalse([self.payload isEqualToPayload:emptyPayload], @"A payload should not be equal to a different payload");
}

/**
 * Test that payloadDictionary has the full expected payload
 */
- (void)testPayloadDictionaryFullPayload {
    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];

    // identity hints
    NSDictionary *identityHints = [dict valueForKey:kUAChannelIdentityHintsKey];
    XCTAssertNotNil(identityHints, @"identity hints should be present");
    XCTAssertEqualObjects(self.payload.userID, [identityHints valueForKey:kUAChannelUserIDKey], @"user ID should be present");
    XCTAssertEqualObjects(self.payload.deviceID, [identityHints valueForKey:kUAChannelDeviceIDKey], @"device ID should be present");

    // channel specific items
    NSDictionary *channel = [dict valueForKey:kUAChannelKey];
    XCTAssertEqualObjects(@"ios", [channel valueForKey:kUAChannelDeviceTypeKey], @"device type should be present");
    XCTAssertEqualObjects([NSNumber numberWithBool:self.payload.optedIn], [channel valueForKey:kUAChannelOptInKey], @"opt-in should be present");
    XCTAssertEqualObjects(self.payload.pushAddress, [channel valueForKey:kUAChannelPushAddressKey], @"push address should be present");
    XCTAssertEqualObjects(self.payload.alias, [channel valueForKey:kUAChannelAliasJSONKey], @"alias should be present");
    XCTAssertEqualObjects([NSNumber numberWithBool:self.payload.setTags], [channel valueForKey:kUAChannelSetTagsKey], @"set tags should be present");
    XCTAssertEqualObjects(self.payload.tags, [channel valueForKey:kUAChannelTagsJSONKey], @"tags should be present");

    // iOS specific items
    NSDictionary *ios = [channel valueForKey:kUAChanneliOSKey];
    XCTAssertNotNil(ios, @"ios should be present");
    XCTAssertEqualObjects(self.payload.badge, [ios valueForKey:kUAChannelBadgeJSONKey], @"badge should be present");
    XCTAssertEqualObjects(self.payload.quietTime, [ios valueForKey:kUAChannelQuietTimeJSONKey], @"quiet time should be present");
    XCTAssertEqualObjects(self.payload.timeZone, [ios valueForKey:kUAChannelTimeZoneJSONKey], @"timezone should be present");
}

/**
 * Test payloadDictionary when tags are empty or nil
 */
- (void)testPayloadDictionaryEmptyTags {
    self.payload.tags = nil;
    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];
    NSDictionary *channel = [dict valueForKey:kUAChannelKey];
    XCTAssertNil([channel valueForKey:kUAChannelTagsJSONKey], @"tags should be nil");

    // Verify tags is not nil, but an empty nsarray
    self.payload.tags = @[];
    dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];
    channel = [dict valueForKey:kUAChannelKey];
    XCTAssertEqualObjects(self.payload.tags, [channel valueForKey:kUAChannelTagsJSONKey], @"tags should be nil");
}

/**
 * Test that tags are not sent when setTags is false
 */
- (void)testPayloadDictionaryNoTags {
    self.payload.setTags = NO;

    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];
    NSDictionary *channel = [dict valueForKey:kUAChannelKey];

    channel = [dict valueForKey:kUAChannelKey];
    XCTAssertNil([channel valueForKey:kUAChannelTagsJSONKey], @"tags should be nil");
}

/**
 * Test that an empty iOS section is not included
 */
- (void)testPayloadDictionaryEmptyiOSSection {
    self.payload.badge = nil;
    self.payload.quietTime = nil;
    self.payload.timeZone = nil;

    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];
    XCTAssertNil([dict valueForKey:kUAChanneliOSKey], @"iOS section should not be included in the payload");
}

/**
 * Test that an empty identity hints section is not included
 */
- (void)testPayloadDictionaryEmptyIdentityHints {
    self.payload.deviceID = nil;
    self.payload.userID = nil;

    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];
    XCTAssertNil([dict valueForKey:kUAChannelIdentityHintsKey], @"identity hints section should not be included in the payload");
}

/**
 * Test that an empty alias is not included
 */
- (void)testPayloadDictionaryEmptyAlias {
    self.payload.alias = @"";

    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];
    XCTAssertNil([dict valueForKey:kUAChannelAliasJSONKey], @"Alias should not be included in the payload");
}

/**
 * Test that an alias with just spaces is not included
 */
- (void)testPayloadDictionarySpacesAlias {
    self.payload.alias = @"     ";

    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];
    XCTAssertNil([dict valueForKey:kUAChannelAliasJSONKey], @"Alias should not be included in the payload");
}

/**
 * Test that an alias with spaces is trimmed and included
 */
- (void)testPayloadDictionarySpacesTrimmedAlias  {
    self.payload.alias = @"     fakeAlias     ";

    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];
    NSDictionary *channel = [dict valueForKey:kUAChannelKey];
    XCTAssertEqualObjects(self.payload.alias, [channel valueForKey:kUAChannelAliasJSONKey], @"alias should be present");
}

/**
 * Test that a nil alias is not included
 */
- (void)testPayloadDictionaryNilAlias {
    self.payload.alias = nil;

    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:[self.payload payloadDictionary]];
    XCTAssertNil([dict valueForKey:kUAChannelAliasJSONKey], @"Alias should not be included in the payload");
}


// Helpers

- (NSMutableDictionary *)buildQuietTimeWithStartDate:(NSDate *)startDate withEndDate:(NSDate *)endDate {

    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSString *fromStr = [NSString stringWithFormat:@"%ld:%02ld",
                         (long)[cal components:NSHourCalendarUnit fromDate:startDate].hour,
                         (long)[cal components:NSMinuteCalendarUnit fromDate:startDate].minute];

    NSString *toStr = [NSString stringWithFormat:@"%ld:%02ld",
                       (long)[cal components:NSHourCalendarUnit fromDate:endDate].hour,
                       (long)[cal components:NSMinuteCalendarUnit fromDate:endDate].minute];

    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            fromStr, UAPushQuietTimeStartKey,
            toStr, UAPushQuietTimeEndKey, nil];
    
}


@end
