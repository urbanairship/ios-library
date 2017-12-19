/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UALegacyInAppResolutionEvent+Internal.h"
#import "UALegacyInAppMessage.h"
#import "UAUtils.h"

@interface UALegacyInAppResolutionEventTest : UABaseTest
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@property (nonatomic, strong) UALegacyInAppMessage *message;
@end

@implementation UALegacyInAppResolutionEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [self mockForClass:[UAAnalytics class]];
    self.airship = [self mockForClass:[UAirship class]];

    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];

    self.message = [[UALegacyInAppMessage alloc] init];
    self.message.identifier = [NSUUID UUID].UUIDString;
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];
    [super tearDown];
}

/**
 * Test in-app replaced resolution event.
 */
- (void)testReplacedResolutionEvent {
    UALegacyInAppMessage *replacement = [[UALegacyInAppMessage alloc] init];
    replacement.identifier = [NSUUID UUID].UUIDString;

    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];


    NSDictionary *expectedResolution = @{ @"type": @"replaced",
                                          @"replacement_id": replacement.identifier };

    NSDictionary *expectedData = @{ @"id": self.message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolution };

    UALegacyInAppResolutionEvent *event = [UALegacyInAppResolutionEvent replacedResolutionWithMessageID:self.message.identifier replacement:replacement.identifier];

    [self verifyEvent:event expectedData:expectedData];
}

/**
 * Test in-app direct open resolution event.
 */
- (void)testDirectOpenResolutionEvent {
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];

    NSDictionary *expectedResolution = @{ @"type": @"direct_open" };

    NSDictionary *expectedData = @{ @"id": self.message.identifier,
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolution };


    UALegacyInAppResolutionEvent *event = [UALegacyInAppResolutionEvent directOpenResolutionWithMessageID:self.message.identifier];

    [self verifyEvent:event expectedData:expectedData];
}


- (void)verifyEvent:(UALegacyInAppResolutionEvent *)event expectedData:(NSDictionary *)expectedData {
    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution", @"Event type is unexpected.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
    XCTAssertTrue([event isValid], @"Event should be valid if it has a in-app message ID.");
}

@end
