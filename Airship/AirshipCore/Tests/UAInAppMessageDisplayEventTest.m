/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UABaseTest.h"
#import "UAAnalytics.h"
#import "UAirship+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"

@interface UAInAppMessageDisplayEventTest : UABaseTest
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@property (nonatomic, strong) UAInAppMessageBannerDisplayContent *displayContent;
@property (nonatomic, copy) NSDictionary<NSString*, NSString*> *renderedLocale;
@end

@implementation UAInAppMessageDisplayEventTest


- (void)setUp {
    [super setUp];

    self.displayContent = [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.placement = UAInAppMessageBannerPlacementTop;
        builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;

        UAInAppMessageTextInfo *heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"Here is a headline!";
        }];
        builder.heading = heading;

        UAInAppMessageTextInfo *buttonTex = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"Dismiss";
        }];

        UAInAppMessageButtonInfo *button = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = buttonTex;
            builder.identifier = @"button";
        }];

        builder.buttons = @[button];
    }];

    self.analytics = [self mockForClass:[UAAnalytics class]];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];

    self.airship = [self mockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.analytics] sharedAnalytics];

    [UAirship setSharedAirship:self.airship];

    self.renderedLocale = @{@"language" : @"en", @"country" : @"US"};
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];
    [super tearDown];
}

- (void)testEventData {
    UAInAppMessage *remoteDataMessage = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.identifier = @"remote-data-message";
        builder.source = UAInAppMessageSourceRemoteData;
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.displayContent = self.displayContent;
        builder.renderedLocale = @{@"language" : @"en", @"country" : @"US"};
    }];

    UAInAppMessageDisplayEvent *event = [UAInAppMessageDisplayEvent eventWithMessage:remoteDataMessage];

    NSDictionary *expectedData = @{ @"id": @{  @"message_id": @"remote-data-message",
                                               @"campaigns": @{@"some": @"campaigns object"} },
                                    @"source": @"urban-airship",
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"locale" : self.renderedLocale
                                    };

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_display");
    XCTAssertNotNil(event.eventID);
    XCTAssertTrue([event isValid]);

    UAInAppMessage *legacyMessage = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.identifier = @"legacy-message";
        builder.source = UAInAppMessageSourceLegacyPush;
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.displayContent = self.displayContent;
    }];

    event = [UAInAppMessageDisplayEvent eventWithMessage:legacyMessage];

    expectedData = @{ @"id": @"legacy-message",
                      @"source": @"urban-airship",
                      @"conversion_send_id": [self.analytics conversionSendID],
                      @"conversion_metadata": [self.analytics conversionPushMetadata] };

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_display");
    XCTAssertNotNil(event.eventID);
    XCTAssertTrue([event isValid]);

    UAInAppMessage *appDefined = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.identifier = @"app-defined-message";
        builder.source = UAInAppMessageSourceAppDefined;
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.displayContent = self.displayContent;
    }];

    event = [UAInAppMessageDisplayEvent eventWithMessage:appDefined];

    expectedData = @{ @"id": @{ @"message_id": @"app-defined-message" },
                      @"source": @"app-defined",
                      @"conversion_send_id": [self.analytics conversionSendID],
                      @"conversion_metadata": [self.analytics conversionPushMetadata] };

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_display");
    XCTAssertNotNil(event.eventID);
    XCTAssertTrue([event isValid]);
}

@end
