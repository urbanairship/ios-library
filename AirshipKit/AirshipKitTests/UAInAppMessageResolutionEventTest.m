/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAAnalytics.h"
#import "UAirship+Internal.h"
#import "UAInAppMessageResolutionEvent+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAUtils+Internal.h"
#import "UAInAppMessageFullScreenDisplayContent.h"

@interface UAInAppMessageResolutionEventTest : UABaseTest
@property (nonatomic, strong) id analytics;
@property (nonatomic, strong) id airship;
@property (nonatomic, strong) UAInAppMessageFullScreenDisplayContent *displayContent;
@property (nonatomic, strong) NSDictionary *renderedLocale;
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

    self.displayContent = [UAInAppMessageFullScreenDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageFullScreenDisplayContentBuilder *builder) {
        builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;

        UAInAppMessageTextInfo *heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"Here is a headline!";
        }];
        builder.heading = heading;



        UAInAppMessageButtonInfo *buttonOne = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Dismiss";
            }];
            builder.identifier = @"button";
        }];

        UAInAppMessageButtonInfo *buttonTwo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = [@"" stringByPaddingToLength:31 withString:@"TEXT" startingAtIndex:0];
            }];
            builder.identifier = @"long_button_text";
        }];

        UAInAppMessageButtonInfo *buttonThree = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = [@"" stringByPaddingToLength:30 withString:@"TEXT" startingAtIndex:0];
            }];
            builder.identifier = @"exact_button_description";
        }];

        builder.buttons = @[buttonOne, buttonTwo, buttonThree];
    }];

    self.renderedLocale = @{@"language" : @"en", @"country" : @"US"};
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
                                    @"resolution": @{ @"type": @"direct_open" }
                                    };


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
                                                      @"replacement_id": @"replacement id"}
                                    };

    UAInAppMessageResolutionEvent *event = [UAInAppMessageResolutionEvent legacyReplacedEventWithMessageID:@"message id" replacementID:@"replacement id"];

    XCTAssertEqualObjects(event.data, expectedData);
}


/**
 * Test in-app expired resolution event.
 */
- (void)testExpiredResolutionEvent {
    NSDate *expired = [NSDate date];
    NSDictionary *expectedResolutionData =  @{ @"type": @"expired",
                                               @"expiry": [[UAUtils ISODateFormatterUTCWithDelimiter] stringFromDate:expired]
                                               };

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
    } expectedResolutionData:expectedResolutionData];
}

/**
 * Test in-app button clicked resolution event with a label only takes the first 30 characters.
 */
- (void)testButtonClickedResolutionLongLabel {
    NSDictionary *expectedResolutionData = @{ @"type": @"button_click",
                                              @"button_id": self.displayContent.buttons[1].identifier,
                                              @"button_description": [self.displayContent.buttons[1].label.text substringToIndex:30],
                                              @"display_time": @"3.141"};

    UAInAppMessageResolution *resolution = [UAInAppMessageResolution buttonClickResolutionWithButtonInfo:self.displayContent.buttons[1]];
    [self verifyEventWithEventBlock:^UAInAppMessageResolutionEvent *(UAInAppMessage *message) {
        return [UAInAppMessageResolutionEvent eventWithMessage:message resolution:resolution displayTime:3.141];
    } expectedResolutionData:expectedResolutionData];
}

/**
 * Test in-app button clicked resolution event with a label only takes the first 30 characters.
 */
- (void)testButtonClickedResolutionMaxDescriptionLength {
    NSDictionary *expectedResolutionData = @{ @"type": @"button_click",
                                              @"button_id": self.displayContent.buttons[2].identifier,
                                              @"button_description": self.displayContent.buttons[2].label.text,
                                              @"display_time": @"3.141"};

    UAInAppMessageResolution *resolution = [UAInAppMessageResolution buttonClickResolutionWithButtonInfo:self.displayContent.buttons[2]];

    [self verifyEventWithEventBlock:^UAInAppMessageResolutionEvent *(UAInAppMessage *message) {
        return [UAInAppMessageResolutionEvent eventWithMessage:message resolution:resolution displayTime:3.141];
    } expectedResolutionData:expectedResolutionData];
}

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
    } expectedResolutionData:expectedResolutionData];
}

- (void)verifyEventWithEventBlock:(UAInAppMessageResolutionEvent * (^)(UAInAppMessage *))eventBlock
           expectedResolutionData:(NSDictionary *)expectedResolutionData {

    UAInAppMessage *remoteDataMessage = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder *builder) {
        builder.identifier = @"remote-data-message";
        builder.source = UAInAppMessageSourceRemoteData;
        builder.campaigns = @{@"some": @"campaigns object"};
        builder.displayContent = self.displayContent;
        builder.renderedLocale = self.renderedLocale;
    }];

    UAInAppMessageResolutionEvent *event = eventBlock(remoteDataMessage);

    NSDictionary *expectedData = @{ @"id": @{  @"message_id": @"remote-data-message",
                                               @"campaigns": @{@"some": @"campaigns object"} },
                                    @"source": @"urban-airship",
                                    @"conversion_send_id": [self.analytics conversionSendID],
                                    @"conversion_metadata": [self.analytics conversionPushMetadata],
                                    @"resolution": expectedResolutionData,
                                    @"locale" : self.renderedLocale
                                    };

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

