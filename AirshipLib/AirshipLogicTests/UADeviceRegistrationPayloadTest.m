
/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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

#define kUADeviceRegistrationPayloadTestStartHour 1
#define kUADeviceRegistrationPayloadTestStartMinute 30
#define kUADeviceRegistrationPayloadTestEndHour 3
#define kUADeviceRegistrationPayloadTestEndMinute 45

#import "UADeviceRegistrationPayloadTest.h"
#import "UADeviceRegistrationPayload.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAPush+Internal.h"

@interface UADeviceRegistrationPayloadTest()
@property (nonatomic, strong) UADeviceRegistrationPayload *payload;
@property (nonatomic, strong) UADeviceRegistrationPayload *emptyPayload;
@property (nonatomic, copy) NSString *alias;
@property (nonatomic, strong) NSArray *tags;
@property (nonatomic, strong) NSMutableDictionary *quietTime;
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSDate *endDate;
@property (nonatomic, copy) NSString *timeZone;
@property (nonatomic, strong) NSNumber *badge;
@end

@implementation UADeviceRegistrationPayloadTest

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

- (NSDate *)dateWithHour:(NSInteger)hour withMinute:(NSInteger)minute {
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [gregorian components:NSYearCalendarUnit fromDate:[NSDate date]];

    components.hour = hour;
    components.minute = minute;
    return [gregorian dateFromComponents:components];
}

/* setup and teardown */

- (void)setUp {
    [super setUp];

    self.startDate = [self dateWithHour:kUADeviceRegistrationPayloadTestStartHour withMinute:kUADeviceRegistrationPayloadTestStartMinute];
    self.endDate = [self dateWithHour:kUADeviceRegistrationPayloadTestEndHour withMinute:kUADeviceRegistrationPayloadTestEndMinute];

    
    self.alias = @"foo";
    self.tags = @[@"bar", @"baz"];
    self.timeZone = @"timezone";
    self.quietTime = [self buildQuietTimeWithStartDate:self.startDate withEndDate:self.endDate];
    self.badge = [NSNumber numberWithInteger:1];


    self.payload = [UADeviceRegistrationPayload payloadWithAlias:self.alias
                                                        withTags:self.tags
                                                    withTimeZone:self.timeZone
                                                   withQuietTime:self.quietTime
                                                       withBadge:self.badge];

    self.emptyPayload = [UADeviceRegistrationPayload payloadWithAlias:nil withTags:nil withTimeZone:nil withQuietTime:nil withBadge:nil];
}

- (void)tearDown {
    self.alias = nil;
    self.tags = nil;
    self.timeZone = nil;
    self.quietTime = nil;
    self.badge = nil;
    self.payload = nil;
    self.emptyPayload = nil;
    self.startDate = nil;
    self.endDate = nil;
    [super tearDown];
}

/* tests */

- (void)verifyDictionary:(NSDictionary *)dict {
    XCTAssertNotNil(dict, @"dictionary should not be nil");
    XCTAssertEqualObjects(self.alias, [dict valueForKey:kUAPushAliasJSONKey], @"alias should be present");
    XCTAssertEqualObjects(self.tags, [dict valueForKey:kUAPushMultipleTagsJSONKey], @"tags should be present");
    XCTAssertEqualObjects(self.timeZone, [dict valueForKey:kUAPushTimeZoneJSONKey], @"timezone should be present");
    XCTAssertEqualObjects(self.quietTime, [dict valueForKey:kUAPushQuietTimeJSONKey], @"quiet time should be present");
    XCTAssertEqualObjects(self.badge, [dict valueForKey:kUAPushBadgeJSONKey], @"badge should be present");
}

//nil arguments to the payload constructor should result in their keys not being present in the resulting dictionary
- (void)verifyEmptyDictionary:(NSDictionary *)dict {
    XCTAssertNil([dict valueForKey:kUAPushAliasJSONKey], @"alias should not be present");
    XCTAssertNil([dict valueForKey:kUAPushMultipleTagsJSONKey], @"tags should not be present");
    XCTAssertNil([dict valueForKey:kUAPushTimeZoneJSONKey], @"timezone should not be present");
    XCTAssertNil([dict valueForKey:kUAPushQuietTimeJSONKey], @"quiet time should not be present");
    XCTAssertNil([dict valueForKey:kUAPushBadgeJSONKey], @"badge should not be present");
}

- (void)testAsDictionary {
    [self verifyDictionary:[self.payload asDictionary]];
    [self verifyEmptyDictionary:[self.emptyPayload asDictionary]];
}

- (void)testAsJSONString {
    [self verifyDictionary:[NSJSONSerialization objectWithString:[self.payload asJSONString]]];
    [self verifyEmptyDictionary:[NSJSONSerialization objectWithString:[self.emptyPayload asJSONString]]];
}

- (void)testAsJSONData {
    NSString *jsonString = [[NSString alloc] initWithData:[self.payload asJSONData] encoding:NSUTF8StringEncoding];
    [self verifyDictionary:[NSJSONSerialization objectWithString:jsonString]];
    NSString *emptyJSONString = [[NSString alloc] initWithData:[self.emptyPayload asJSONData] encoding:NSUTF8StringEncoding];
    [self verifyEmptyDictionary:[NSJSONSerialization objectWithString:emptyJSONString]];
}

@end
