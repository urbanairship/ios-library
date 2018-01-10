/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAAnalytics.h"
#import "UAirship+Internal.h"
#import "UAInAppMessageResolutionEvent+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAUtils.h"
#import "UAInAppMessageBannerDisplayContent.h"

@interface UAInAppMessageResolutionEventTest : UABaseTest
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@property (nonatomic, strong) UAInAppMessageBannerDisplayContent *displayContent;
@end

@implementation UAInAppMessageResolutionEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [self mockForClass:[UAAnalytics class]];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionSendID];
    [[[self.analytics stub] andReturn:[NSUUID UUID].UUIDString] conversionPushMetadata];

    self.airship = [self mockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.analytics] sharedAnalytics];
    [UAirship setSharedAirship:self.airship];

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
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];
    [super tearDown];
}

/**
 * Test in-app direct open resolution event.
 */
- (void)testLegacyDirectOpenResolutionEvent {
    NSDictionary *expectedData = @{ @"id": @"message id",
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"source": @"urban-airship",
                                    @"resolution": @{ @"type": @"direct_open" } };


    UAInAppMessageResolutionEvent *event = [UAInAppMessageResolutionEvent legacyDirectOpenEventWithMessageID:@"message id"];
    XCTAssertEqualObjects(event.data, expectedData);
}

/**
 * Test in-app replaced resolution event.
 */
- (void)testLegacyReplacedResolutionEvent {
    NSDictionary *expectedData = @{ @"id": @"message id",
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"source": @"urban-airship",
                                    @"resolution": @{ @"type": @"replaced",
                                                      @"replacement_id": @"replacement id"} };

    UAInAppMessageResolutionEvent *event = [UAInAppMessageResolutionEvent legacyReplacedEventWithMessageID:@"message id" replacementID:@"replacement id"];

    XCTAssertEqualObjects(event.data, expectedData);
}


/**
 * Test in-app expired resolution event.
 */
- (void)testExpiredResolutionEvent {
    NSDate *expired = [NSDate date];
    NSDictionary *expectedResolutionData =  @{ @"type": @"expired",
                                               @"expiry": [[UAUtils ISODateFormatterUTCWithDelimiter] stringFromDate:expired] };


    [self verifyEventWithEventBlock:^UAInAppMessageResolutionEvent *(UAInAppMessage *message) {
        return [UAInAppMessageResolutionEvent eventWithExpiredMessage:message expiredDate:expired];
    } expectedResolutionData:expectedResolutionData];
}



/**
 * Test in-app button clicked resolution event.
 */
- (void)testButtonClickedResolutionEvent {
    NSDictionary *expectedResolutionData = @{ @"type": @"button_click",
                                          @"button_id": self.displayContent.buttons[0].identifier,
                                          @"button_description": self.displayContent.buttons[0].label.text,
                                          @"display_time": @"3.141"};

    UAInAppMessageResolution *resolution = [UAInAppMessageResolution buttonClickResolutionWithButtonInfo:self.displayContent.buttons[0]];
    [self verifyEventWithEventBlock:^UAInAppMessageResolutionEvent *(UAInAppMessage *message) {
        return [UAInAppMessageResolutionEvent eventWithMessage:message resolution:resolution displayTime:3.141];
    } expectedResolutionData:expectedResolutionData];}


/**
 * Test in-app message clicked resolution event.
 */
- (void)testMessageClickedResolutionEvent {
    NSDictionary *expectedResolutionData = @{ @"type": @"message_click",
                                          @"display_time": @"3.141"};

    UAInAppMessageResolution *resolution = [UAInAppMessageResolution messageClickResolution];
    [self verifyEventWithEventBlock:^UAInAppMessageResolutionEvent *(UAInAppMessage *message) {
        return [UAInAppMessageResolutionEvent eventWithMessage:message resolution:resolution displayTime:3.141];
    } expectedResolutionData:expectedResolutionData];
}

/**
 * Test in-app dismisssed resolution event.
 */
- (void)testDismissedResolutionEvent {
    NSDictionary *expectedResolutionData = @{ @"type": @"user_dismissed",
                                          @"display_time": @"3.141"};

    UAInAppMessageResolution *resolution = [UAInAppMessageResolution userDismissedResolution];
    [self verifyEventWithEventBlock:^UAInAppMessageResolutionEvent *(UAInAppMessage *message) {
        return [UAInAppMessageResolutionEvent eventWithMessage:message resolution:resolution displayTime:3.141];
    } expectedResolutionData:expectedResolutionData];}

/**
 * Test in-app timed out resolution event.
 */
- (void)testTimedOutResolutionEvent {
    NSDictionary *expectedResolutionData = @{ @"type": @"timed_out",
                                          @"display_time": @"3.141"};

    UAInAppMessageResolution *resolution = [UAInAppMessageResolution timedOutResolution];
    [self verifyEventWithEventBlock:^UAInAppMessageResolutionEvent *(UAInAppMessage *message) {
        return [UAInAppMessageResolutionEvent eventWithMessage:message resolution:resolution displayTime:3.141];
    } expectedResolutionData:expectedResolutionData];}

- (void)verifyEventWithEventBlock:(UAInAppMessageResolutionEvent * (^)(UAInAppMessage *))eventBlock
           expectedResolutionData:(NSDictionary *)expectedResolutionData {

    UAInAppMessage *remoteDataMessage = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.identifier = @"remote-data-message";
        builder.source = UAInAppMessageSourceRemoteData;
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.displayContent = self.displayContent;
    }];

    UAInAppMessageResolutionEvent *event = eventBlock(remoteDataMessage);

    NSDictionary *expectedData = @{ @"id": @{  @"message_id": @"remote-data-message",
                                               @"campaigns": @{@"some": @"campaigns object"} },
                                    @"source": @"urban-airship",
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolutionData };

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
    XCTAssertNotNil(event.eventID);
    XCTAssertTrue([event isValid]);


    UAInAppMessage *legacyMessage = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.identifier = @"legacy-message";
        builder.source = UAInAppMessageSourceLegacyPush;
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.displayContent = self.displayContent;
    }];

    event = eventBlock(legacyMessage);

    expectedData = @{ @"id": @"legacy-message",
                      @"source": @"urban-airship",
                      @"conversion_send_id": [self.analytics conversionSendID],
                      @"conversion_metadata": [self.analytics conversionPushMetadata],
                      @"resolution": expectedResolutionData };

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
    XCTAssertNotNil(event.eventID);
    XCTAssertTrue([event isValid]);

    UAInAppMessage *appDefined = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.identifier = @"app-defined-message";
        builder.source = UAInAppMessageSourceAppDefined;
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.displayContent = self.displayContent;
    }];

    event = eventBlock(appDefined);

    expectedData = @{ @"id": @{ @"message_id": @"app-defined-message" },
                      @"source": @"app-defined",
                      @"conversion_send_id": [self.analytics conversionSendID],
                      @"conversion_metadata": [self.analytics conversionPushMetadata],
                      @"resolution": expectedResolutionData };

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
    XCTAssertNotNil(event.eventID);
    XCTAssertTrue([event isValid]);
}

@end

