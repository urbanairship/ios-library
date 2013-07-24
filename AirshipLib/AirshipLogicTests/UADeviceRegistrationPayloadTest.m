
#define kUADeviceRegistrationPayloadTestStartHour 1
#define kUADeviceRegistrationPayloadTestStartMinute 30
#define kUADeviceRegistrationPayloadTestEndHour 3
#define kUADeviceRegistrationPayloadTestEndMinute 45

#import "UADeviceRegistrationPayloadTest.h"
#import "UADeviceRegistrationPayload.h"
#import "UAPush+Internal.h"
#import "UA_SBJSON.h"

@interface UADeviceRegistrationPayloadTest()
@property(nonatomic, retain) UADeviceRegistrationPayload *payload;
@property(nonatomic, retain) UADeviceRegistrationPayload *emptyPayload;
@property(nonatomic, copy) NSString *alias;
@property(nonatomic, retain) NSArray *tags;
@property(nonatomic, retain) NSMutableDictionary *quietTime;
@property(nonatomic, retain) NSDate *startDate;
@property(nonatomic, retain) NSDate *endDate;
@property(nonatomic, copy) NSString *timeZone;
@property(nonatomic, retain) NSNumber *badge;
@end

@implementation UADeviceRegistrationPayloadTest

//note: the fact that is even needed suggests we would probably be better off refactoring this outside of UAPush,
//or at least separating the building of the dictionary from setting UAPush property state.
- (NSMutableDictionary *)buildQuietTimeWithStartDate:(NSDate *)startDate withEndDate:(NSDate *)endDate {
   
    NSCalendar *cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    NSString *fromStr = [NSString stringWithFormat:@"%d:%02d",
                         [cal components:NSHourCalendarUnit fromDate:startDate].hour,
                         [cal components:NSMinuteCalendarUnit fromDate:startDate].minute];

    NSString *toStr = [NSString stringWithFormat:@"%d:%02d",
                       [cal components:NSHourCalendarUnit fromDate:endDate].hour,
                       [cal components:NSMinuteCalendarUnit fromDate:endDate].minute];

    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      fromStr, UAPushQuietTimeStartKey,
                      toStr, UAPushQuietTimeEndKey, nil];

}

- (NSDate *)dateWithHour:(NSInteger)hour withMinute:(NSInteger)minute {
    
    NSCalendar *gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
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
    STAssertNotNil(dict, @"dictionary should not be nil");
    STAssertEqualObjects(self.alias, [dict valueForKey:UAPushAliasJSONKey], @"alias should be present");
    STAssertEqualObjects(self.tags, [dict valueForKey:UAPushMultipleTagsJSONKey], @"tags should be present");
    STAssertEqualObjects(self.timeZone, [dict valueForKey:UAPushTimeZoneJSONKey], @"timezone should be present");
    STAssertEqualObjects(self.quietTime, [dict valueForKey:UAPushQuietTimeJSONKey], @"quiet time should be present");
    STAssertEqualObjects(self.badge, [dict valueForKey:UAPushBadgeJSONKey], @"badge should be present");
}

//nil arguments to the payload constructor should result in their keys not being present in the resulting dictionary
- (void)verifyEmptyDictionary:(NSDictionary *)dict {
    STAssertNil([dict valueForKey:UAPushAliasJSONKey], @"alias should not be present");
    STAssertNil([dict valueForKey:UAPushMultipleTagsJSONKey], @"tags should not be present");
    STAssertNil([dict valueForKey:UAPushTimeZoneJSONKey], @"timezone should not be present");
    STAssertNil([dict valueForKey:UAPushQuietTimeJSONKey], @"quiet time should not be present");
    STAssertNil([dict valueForKey:UAPushBadgeJSONKey], @"badge should not be present");
}

- (void)testAsDictionary {
    [self verifyDictionary:[self.payload asDictionary]];
    [self verifyEmptyDictionary:[self.emptyPayload asDictionary]];
}

- (void)testAsJSONString {
    UA_SBJsonParser *parser = [[[UA_SBJsonParser alloc] init] autorelease];
    [self verifyDictionary:[parser objectWithString:[self.payload asJSONString]]];
    [self verifyEmptyDictionary:[parser objectWithString:[self.emptyPayload asJSONString]]];
}

- (void)testAsJSONData {
    UA_SBJsonParser *parser = [[[UA_SBJsonParser alloc] init] autorelease];
    NSString *jsonString = [[[NSString alloc] initWithData:[self.payload asJSONData] encoding:NSUTF8StringEncoding] autorelease];
    [self verifyDictionary:[parser objectWithString:jsonString]];
    NSString *emptyJSONString = [[[NSString alloc] initWithData:[self.emptyPayload asJSONData] encoding:NSUTF8StringEncoding] autorelease];
    [self verifyEmptyDictionary:[parser objectWithString:emptyJSONString]];
}

@end
