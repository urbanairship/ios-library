
#import "UADeviceRegistrationData.h"
#import "UADeviceRegistrationDataTest.h"

@implementation UADeviceRegistrationDataTest

- (void)testIsEqual {

    UADeviceRegistrationPayload *payload = [UADeviceRegistrationPayload payloadWithAlias:@"foo" withTags:nil withTimeZone:@"timezone" withQuietTime:nil withBadge:[NSNumber numberWithInteger:1]];

    //at this point the two instances should be equal by value
    UADeviceRegistrationData *data = [UADeviceRegistrationData dataWithDeviceToken:@"blah" withPayload:payload pushEnabled:NO];
    UADeviceRegistrationData *data2 = [UADeviceRegistrationData dataWithDeviceToken:@"blah" withPayload:payload pushEnabled:NO];

    STAssertEqualObjects(data, data2, @"UADeviceRegistrationData should compare by value, not by pointer");

    //the rest of these comparisons should result in inequality
    UADeviceRegistrationPayload *data3 = [UADeviceRegistrationData dataWithDeviceToken:@"adfsjlkfadsljk" withPayload:payload pushEnabled:NO];
    STAssertFalse([data isEqual:data3], @"changing the device token should trigger inequality");

    UADeviceRegistrationData *data4 = [UADeviceRegistrationData dataWithDeviceToken:@"blah" withPayload:payload pushEnabled:YES];
    STAssertFalse([data isEqual:data4], @"changing the push enabled status should trigger inequality");

    UADeviceRegistrationPayload *payload2 = [UADeviceRegistrationPayload payloadWithAlias:@"bar" withTags:nil withTimeZone:@"timezone" withQuietTime:nil withBadge:[NSNumber numberWithInteger:1]];
    UADeviceRegistrationData *data5 = [UADeviceRegistrationData dataWithDeviceToken:@"blah" withPayload:payload2 pushEnabled:NO];
    STAssertFalse([data isEqual:data5], @"changing the payload should trigger inequality");
}

@end
