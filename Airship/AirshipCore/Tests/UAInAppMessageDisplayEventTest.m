/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageDisplayEvent+Internal.h"
#import "UABaseTest.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "AirshipTests-Swift.h"

@interface UAInAppMessageDisplayEventTest : UABaseTest
@property(nonatomic, strong) UATestAnalytics *analytics;
@property(nonatomic, strong) UATestAirshipInstance *airship;
@property (nonatomic, strong) UAInAppMessageBannerDisplayContent *displayContent;
@property (nonatomic, copy) NSDictionary<NSString*, NSString*> *renderedLocale;
@end

@implementation UAInAppMessageDisplayEventTest


- (void)setUp {
    [super setUp];

    self.analytics = [[UATestAnalytics alloc] init];
    self.analytics.conversionSendID = [NSUUID UUID].UUIDString;
    self.analytics.conversionPushMetadata = [NSUUID UUID].UUIDString;
    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.analytics];
    [self.airship makeShared];
    
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

    self.renderedLocale = @{@"language" : @"en", @"country" : @"US"};
}

- (void)testEventData {
    UAInAppMessage *remoteDataMessage = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.source = UAInAppMessageSourceRemoteData;
        builder.displayContent = self.displayContent;
        builder.renderedLocale = @{@"language" : @"en", @"country" : @"US"};
    }];

    UAInAppMessageDisplayEvent *event = [UAInAppMessageDisplayEvent eventWithMessageID:@"remote-data-message"
                                                                               message:remoteDataMessage
                                                                             campaigns:@{@"some": @"campaigns object"} reportingContext:@{}];

    NSDictionary *expectedData = @{ @"id": @{  @"message_id": @"remote-data-message",
                                               @"campaigns": @{@"some": @"campaigns object"} },
                                    @"source": @"urban-airship",
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"locale" : self.renderedLocale,
                                    @"context": @{}
                                    }
    ;

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_display");


    UAInAppMessage *legacyMessage = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.source = UAInAppMessageSourceLegacyPush;
        builder.displayContent = self.displayContent;
    }];

    event = [UAInAppMessageDisplayEvent eventWithMessageID:@"legacy-message"
                                                   message:legacyMessage
                                                 campaigns:nil
                                          reportingContext:@{}];

    expectedData = @{ @"id": @"legacy-message",
                      @"source": @"urban-airship",
                      @"conversion_send_id": [self.analytics conversionSendID],
                      @"conversion_metadata": [self.analytics conversionPushMetadata],
                      @"context": @{}
    };

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_display");

    UAInAppMessage *appDefined = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.source = UAInAppMessageSourceAppDefined;
        builder.displayContent = self.displayContent;
    }];

    event = [UAInAppMessageDisplayEvent eventWithMessageID:@"app-defined-message" message:appDefined campaigns:@{@"some": @"campaigns object"} reportingContext:@{}];

    expectedData = @{ @"id": @{ @"message_id": @"app-defined-message" },
                      @"source": @"app-defined",
                      @"conversion_send_id": [self.analytics conversionSendID],
                      @"conversion_metadata": [self.analytics conversionPushMetadata],
                      @"context": @{}
    };

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_display");
}

@end
