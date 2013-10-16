/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAChannelRegistrationPayload.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAPush+Internal.h"

@interface UAChannelRegistrationPayloadTest : XCTestCase

@end

@implementation UAChannelRegistrationPayloadTest
UAChannelRegistrationPayload *payload;

//note: the fact that is even needed suggests we would probably be better off refactoring this outside of UAPush,
//or at least separating the building of the dictionary from setting UAPush property state.
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

- (void)setUp {
    [super setUp];

    NSDictionary *quietTime = [self buildQuietTimeWithStartDate:[NSDate dateWithTimeIntervalSince1970:30]
                                                    withEndDate:[NSDate dateWithTimeIntervalSince1970:100]];

    payload = [[UAChannelRegistrationPayload alloc] init];

    // set up the full payload
    payload.optedIn = YES;
    payload.pushAddress = @"FAKEADDRESS";
    payload.userID = @"fakeUser";
    payload.deviceID = @"fakeDeviceID";
    payload.badge = [NSNumber numberWithInteger:1];
    payload.quietTime =  quietTime;
    payload.timeZone = @"timezone";
    payload.alias = @"fakeAlias";
    payload.tags = @[@"tagOne", @"tagTwo"];
    payload.setTags = YES;
}

- (void)tearDown {

    [super tearDown];
}

/**
 * Test that the hash changes when values change on the dictionary
 */
- (void)testHash {
    NSUInteger hash = [payload hash];
    XCTAssertNotEqual(0, hash, @"Hash should not equal zero");

    payload.alias = @"someAlias";
    XCTAssertNotEqual(hash, [payload hash], @"Hash should change when the payload changes");
}


/**
 * Test that the json has the full expected payload
 */
- (void)testAsJsonFullPayload {
    NSString *jsonString = [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization objectWithString:jsonString];

    NSString *expectedOutput = @"{\"identity_hints\":{\"user_id\":\fakeUser\",\"device_id\":\"fakeDeviceID\"},\"ios\":{\"quiettime\":{\"start\":\"16:00\",\"end\":\"16:01\"},\"tz\":\"timezone\",\"badge\":1},\"tags\":[\"tagOne\",\"tagTwo\"],\"transport\":\"apns\",\"alias\":\"fakeAlias\",\"device_type\":\"ios\",\"opt-in\":true,\"push-address\":\"FAKEADDRESS\",\"set_tags\":true}";


    XCTAssertEqualObjects(jsonString, expectedOutput, @"Unexpected output");

    // Top level items here
    XCTAssertEqualObjects(@"ios", [dict valueForKey:UAChannelDeviceTypeKey], @"device type should be present");
    XCTAssertEqualObjects(@"apns", [dict valueForKey:UAChannelTransportKey], @"transport type should be present");
    XCTAssertEqualObjects([NSNumber numberWithBool:payload.optedIn], [dict valueForKey:UAChannelOptInKey], @"opt-in should be present");
    XCTAssertEqualObjects(payload.pushAddress, [dict valueForKey:UAChannelPushAddressKey], @"push address should be present");
    XCTAssertEqualObjects(payload.alias, [dict valueForKey:UAChannelAliasJSONKey], @"alias should be present");
    XCTAssertEqualObjects([NSNumber numberWithBool:payload.setTags], [dict valueForKey:UAChannelSetTagsKey], @"set tags should be present");
    XCTAssertEqualObjects(payload.tags, [dict valueForKey:UAChannelTagsJSONKey], @"tags should be present");

    // identity hints
    NSDictionary *identityHints = [dict valueForKey:UAChannelIdentityHintsKey];
    XCTAssertNotNil(identityHints, @"identity hints should be present");
    XCTAssertEqualObjects(payload.userID, [identityHints valueForKey:UAChannelUserIDKey], @"user ID should be present");
    XCTAssertEqualObjects(payload.deviceID, [identityHints valueForKey:UAChannelDeviceIDKey], @"device ID should be present");

    // iOS specific items
    NSDictionary *ios = [dict valueForKey:UAChanneliOSKey];
    XCTAssertNotNil(ios, @"ios should be present");
    XCTAssertEqualObjects(payload.badge, [ios valueForKey:UAChannelBadgeJSONKey], @"badge should be present");
    XCTAssertEqualObjects(payload.quietTime, [ios valueForKey:UAChannelQuietTimeJSONKey], @"quiet time should be present");
    XCTAssertEqualObjects(payload.timeZone, [ios valueForKey:UAChannelTimeZoneJSONKey], @"timezone should be present");
}

/**
 * Test when tags are empty or nil
 */
- (void)testAsJsonEmptyTags {
    payload.tags = nil;

    NSString *jsonString = [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization objectWithString:jsonString];
    XCTAssertNil([dict valueForKey:UAChannelTagsJSONKey], @"tags should be nil");

    // Verify tags is not nil, but an empty nsarray
    payload.tags = @[];
    jsonString = [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding];
    dict = [NSJSONSerialization objectWithString:jsonString];
    XCTAssertEqualObjects(payload.tags, [dict valueForKey:UAChannelTagsJSONKey], @"tags should be nil");
}

/**
 * Test that an empty iOS section is not included
 */
- (void)testAsJsonEmptyiOSSection {
    payload.badge = nil;
    payload.quietTime = nil;
    payload.timeZone = nil;

    NSString *jsonString = [[NSString alloc] initWithData:[payload asJSONData] encoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization objectWithString:jsonString];

    XCTAssertNil([dict valueForKey:UAChanneliOSKey], @"iOS section should not be included in the JSON");
}

/**
 * Test that an empty indentity hints section is not included
 */
- (void)testAsJsonEmptyIndentityHints {

}

/* tests */

- (void)verifyJsonData:(NSData *)data {
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization objectWithString:jsonString];

    XCTAssertNotNil(dict, @"dictionary should not be nil");
    XCTAssertEqualObjects(payload.alias, [dict valueForKey:UAChannelAliasJSONKey], @"alias should be present");
    XCTAssertEqualObjects(payload.tags, [dict valueForKey:UAChannelTagsJSONKey], @"tags should be present");
    XCTAssertEqualObjects(payload.timeZone, [dict valueForKey:UAChannelTimeZoneJSONKey], @"timezone should be present");
    XCTAssertEqualObjects(payload.quietTime, [dict valueForKey:UAChannelQuietTimeJSONKey], @"quiet time should be present");
    XCTAssertEqualObjects(payload.badge, [dict valueForKey:UAChannelBadgeJSONKey], @"badge should be present");
}


@end
