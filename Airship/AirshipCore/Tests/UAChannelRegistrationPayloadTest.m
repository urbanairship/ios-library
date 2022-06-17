/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;

@interface UAChannelRegistrationPayloadTest : UABaseTest
@property (nonatomic, strong) UAChannelRegistrationPayload *payload;
@end

@implementation UAChannelRegistrationPayloadTest

- (void)setUp {
    [super setUp];

    UAQuietTime *quietTime = [[UAQuietTime alloc] initWithStart:@"16:00" end:@"16:01"];

    self.payload = [[UAChannelRegistrationPayload alloc] init];
    self.payload.identityHints = [[UAIdentityHints alloc] init];
    self.payload.channel.iOSChannelSettings = [[UAIOSChannelSettings alloc] init];

    // set up the full payload
    self.payload.channel.isOptedIn = YES;
    self.payload.channel.isBackgroundEnabled = YES;
    self.payload.channel.pushAddress = @"FAKEADDRESS";
    self.payload.identityHints.userID = @"fakeUser";
    self.payload.identityHints.accengageDeviceID = @"fakeAccengageDeviceID";
    self.payload.channel.contactID = @"some-contact-id";
    self.payload.channel.iOSChannelSettings.badgeNumber = [NSNumber numberWithInteger:1];
    self.payload.channel.iOSChannelSettings.quietTime = quietTime;
    self.payload.channel.iOSChannelSettings.quietTimeTimeZone = @"quietTimeTimeZone";
    self.payload.channel.timeZone = @"timezone";
    self.payload.channel.language = @"language";
    self.payload.channel.country = @"country";
    self.payload.channel.tags = @[@"tagOne", @"tagTwo"];
    self.payload.channel.setTags = YES;
    self.payload.channel.locationEnabledNumber = @(YES);
    self.payload.channel.sdkVersion = @"SDKVersion";
    self.payload.channel.appVersion = @"appVersion";
    self.payload.channel.deviceModel = @"deviceModel";
    self.payload.channel.deviceOS = @"deviceOS";
    self.payload.channel.carrier = @"carrier";
}

/**
 * Test that the json has the full expected payload
 */
- (void)testAsJsonFullPayload {
    NSData *payloadData = [self.payload encodeWithError:nil];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];

    NSDictionary *expected = @{
        @"channel": @{
                @"app_version": @"appVersion",
                @"background": @(YES),
                @"carrier": @"carrier",
                @"contact_id": @"some-contact-id",
                @"device_model": @"deviceModel",
                @"device_os": @"deviceOS",
                @"device_type": @"ios",
                @"locale_country": @"country",
                @"locale_language": @"language",
                @"location_settings": @(YES),
                @"opt_in": @(YES),
                @"push_address": @"FAKEADDRESS",
                @"sdk_version": @"SDKVersion",
                @"set_tags": @(YES),
                @"tags": @[@"tagOne", @"tagTwo"],
                @"timezone": @"timezone",
                @"is_activity": @(NO),
                @"ios": @{
                    @"badge": @(1),
                    @"quiettime": @{
                            @"end": @"16:01",
                            @"start": @"16:00",
                    },
                    @"tz": @"quietTimeTimeZone"
                }
        },
        @"identity_hints": @{
                @"accengage_device_id": @"fakeAccengageDeviceID",
                @"user_id": @"fakeUser",
        }
    };
    XCTAssertEqualObjects(expected, json);
}

- (void)testEncodeDecode {
    NSError *error = nil;
    NSData *payloadData = [self.payload encodeWithError:&error];
    XCTAssertNil(error);
    UAChannelRegistrationPayload *fromData = [UAChannelRegistrationPayload decode:payloadData error:&error];
    XCTAssertEqualObjects(fromData, self.payload);
    XCTAssertNil(error);
}


/**
 * Test when tags are empty or nil
 */
- (void)testAsJsonEmptyTags {
    self.payload.channel.tags = nil;
    
    NSData *payloadData = [self.payload encodeWithError:nil];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];

    NSDictionary *expected = @{
        @"channel": @{
                @"app_version": @"appVersion",
                @"background": @(YES),
                @"carrier": @"carrier",
                @"contact_id": @"some-contact-id",
                @"device_model": @"deviceModel",
                @"device_os": @"deviceOS",
                @"device_type": @"ios",
                @"locale_country": @"country",
                @"locale_language": @"language",
                @"location_settings": @(YES),
                @"opt_in": @(YES),
                @"push_address": @"FAKEADDRESS",
                @"sdk_version": @"SDKVersion",
                @"set_tags": @(YES),
                @"is_activity": @(NO),
                @"timezone": @"timezone",
                @"ios": @{
                    @"badge": @(1),
                    @"quiettime": @{
                            @"end": @"16:01",
                            @"start": @"16:00",
                    },
                    @"tz": @"quietTimeTimeZone"
                }
        },
        @"identity_hints": @{
                @"accengage_device_id": @"fakeAccengageDeviceID",
                @"user_id": @"fakeUser",
        }
    };
    XCTAssertEqualObjects(expected, json);
}

- (void)testCopy {
    UAChannelRegistrationPayload *copy = [self.payload copy];
    XCTAssertEqualObjects(copy, self.payload);
    
    UAChannelRegistrationPayload *empty = [[UAChannelRegistrationPayload alloc] init];
    UAChannelRegistrationPayload *emptyCopy = [empty copy];
    XCTAssertEqualObjects(emptyCopy, empty);
}

- (void)testMinimalUpdatePayloadSameValues {
    UAChannelRegistrationPayload *minPayload = [self.payload minimizePayloadWithPrevious:self.payload];
    XCTAssertNil(minPayload.channel.country);
    XCTAssertNil(minPayload.channel.language);
    XCTAssertNil(minPayload.channel.timeZone);
    XCTAssertNil(minPayload.channel.tags);
    XCTAssertNil(minPayload.identityHints);
    XCTAssertFalse(minPayload.channel.setTags);
    XCTAssertNil(minPayload.channel.locationEnabledNumber);
    XCTAssertNil(minPayload.channel.sdkVersion);
    XCTAssertNil(minPayload.channel.appVersion);
    XCTAssertNil(minPayload.channel.deviceModel);
    XCTAssertNil(minPayload.channel.deviceOS);
    XCTAssertNil(minPayload.channel.carrier);

    XCTAssertEqual(self.payload.channel.isBackgroundEnabled, minPayload.channel.isBackgroundEnabled);
    XCTAssertEqual(self.payload.channel.isOptedIn, minPayload.channel.isOptedIn);
    XCTAssertEqualObjects(self.payload.channel.pushAddress, minPayload.channel.pushAddress);
    XCTAssertEqualObjects(self.payload.channel.iOSChannelSettings, minPayload.channel.iOSChannelSettings);
}

- (void)testMinimalUpdatePayloadDifferentValues {
    UAChannelRegistrationPayload *copy = [self.payload copy];
    copy.channel.country = @"country CHANGED";
    copy.channel.timeZone = @"timeZone CHANGED";
    copy.channel.language = @"language CHANGED";
    copy.channel.tags = @[@"tags CHANGED"];
    copy.channel.locationEnabledNumber = @(NO);
    copy.channel.sdkVersion = @"SDKVersion CHANGED";
    copy.channel.appVersion = @"appVersion CHANGED";
    copy.channel.deviceModel = @"deviceModel CHANGED";
    copy.channel.deviceOS = @"deviceOS CHANGED";
    copy.channel.carrier = @"carrier CHANGED";

    UAChannelRegistrationPayload *min = [copy minimizePayloadWithPrevious:self.payload];
    NSDictionary *expected = @{
        @"channel": @{
                @"app_version": @"appVersion CHANGED",
                @"background": @(YES),
                @"carrier": @"carrier CHANGED",
                @"contact_id": @"some-contact-id",
                @"device_model": @"deviceModel CHANGED",
                @"device_os": @"deviceOS CHANGED",
                @"device_type": @"ios",
                @"locale_country": @"country CHANGED",
                @"locale_language": @"language CHANGED",
                @"location_settings": @(NO),
                @"opt_in": @(YES),
                @"push_address": @"FAKEADDRESS",
                @"sdk_version": @"SDKVersion CHANGED",
                @"set_tags": @(YES),
                @"is_activity": @(NO),
                @"tags": @[@"tags CHANGED"],
                @"tag_changes": @{
                        @"add": @[@"tags CHANGED"],
                        @"remove": @[@"tagOne", @"tagTwo"]
                },
                @"timezone": @"timeZone CHANGED",
                @"ios": @{
                    @"badge": @(1),
                    @"quiettime": @{
                            @"end": @"16:01",
                            @"start": @"16:00",
                    },
                    @"tz": @"quietTimeTimeZone"
                }
        }
    };
    
    NSData *payloadData = [min encodeWithError:nil];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];

    XCTAssertEqualObjects(expected, json);
}

- (void)testMinimalUpdatePayloadDifferentContactID {
    UAChannelRegistrationPayload *thisPayload = [self.payload copy];
    thisPayload.channel.contactID = @"some-other-contact-id";
    
    UAChannelRegistrationPayload *min = [thisPayload minimizePayloadWithPrevious:self.payload];
    NSDictionary *expected = @{
        @"channel": @{
                @"app_version": @"appVersion",
                @"background": @(YES),
                @"carrier": @"carrier",
                @"contact_id": @"some-other-contact-id",
                @"device_model": @"deviceModel",
                @"device_os": @"deviceOS",
                @"device_type": @"ios",
                @"locale_country": @"country",
                @"locale_language": @"language",
                @"location_settings": @(YES),
                @"opt_in": @(YES),
                @"push_address": @"FAKEADDRESS",
                @"sdk_version": @"SDKVersion",
                @"set_tags": @(NO),
                @"is_activity": @(NO),
                @"timezone": @"timezone",
                @"ios": @{
                    @"badge": @(1),
                    @"quiettime": @{
                            @"end": @"16:01",
                            @"start": @"16:00",
                    },
                    @"tz": @"quietTimeTimeZone"
                }
        }
    };
    
    NSData *payloadData = [min encodeWithError:nil];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
    
    XCTAssertEqualObjects(expected, json);
}


- (void)testMinimalUpdatePayloadChangeToNilContactID {
    UAChannelRegistrationPayload *thisPayload = [self.payload copy];
    thisPayload.channel.contactID = nil;
    
    UAChannelRegistrationPayload *min = [thisPayload minimizePayloadWithPrevious:self.payload];
    NSDictionary *expected = @{
        @"channel": @{
                @"app_version": @"appVersion",
                @"background": @(YES),
                @"carrier": @"carrier",
                @"device_model": @"deviceModel",
                @"device_os": @"deviceOS",
                @"device_type": @"ios",
                @"locale_country": @"country",
                @"locale_language": @"language",
                @"location_settings": @(YES),
                @"opt_in": @(YES),
                @"push_address": @"FAKEADDRESS",
                @"sdk_version": @"SDKVersion",
                @"set_tags": @(NO),
                @"is_activity": @(NO),
                @"timezone": @"timezone",
                @"ios": @{
                    @"badge": @(1),
                    @"quiettime": @{
                            @"end": @"16:01",
                            @"start": @"16:00",
                    },
                    @"tz": @"quietTimeTimeZone"
                }
        }
    };
    
    NSData *payloadData = [min encodeWithError:nil];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
    
    XCTAssertEqualObjects(expected, json);
}

- (void)testMinimalUpdatePayloadNilValues {
    UAChannelRegistrationPayload *copy = [self.payload copy];
    copy.channel.country = nil;
    copy.channel.timeZone = nil;
    copy.channel.language = nil;
    copy.channel.tags = nil;
    copy.channel.locationEnabledNumber = nil;
    copy.channel.sdkVersion = nil;
    copy.channel.appVersion = nil;
    copy.channel.deviceModel = nil;
    copy.channel.deviceOS = nil;
    copy.channel.carrier = nil;
    
    UAChannelRegistrationPayload *min = [copy minimizePayloadWithPrevious:self.payload];
    NSDictionary *expected = @{
        @"channel": @{
                @"background": @(YES),
                @"contact_id": @"some-contact-id",
                @"device_type": @"ios",
                @"opt_in": @(YES),
                @"push_address": @"FAKEADDRESS",
                @"set_tags": @(YES),
                @"is_activity": @(NO),
                @"ios": @{
                    @"badge": @(1),
                    @"quiettime": @{
                            @"end": @"16:01",
                            @"start": @"16:00",
                    },
                    @"tz": @"quietTimeTimeZone"
                }
        }
    };
    
    NSData *payloadData = [min encodeWithError:nil];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:payloadData options:0 error:nil];
    
    XCTAssertEqualObjects(expected, json);
}

@end
