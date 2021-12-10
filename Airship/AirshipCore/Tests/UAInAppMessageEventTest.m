/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "AirshipTests-Swift.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageCustomDisplayContent.h"
#import "UAInAPpReporting+Internal.h"

@interface UAInAppMessageEventTest : XCTestCase
@property(nonatomic, strong) UATestAnalytics *analytics;
@property(nonatomic, strong) UAInAppMessage *message;
@property(nonatomic, copy) NSString *scheduleID;
@end

@implementation UAInAppMessageEventTest

- (void)setUp {
    [super setUp];

    self.message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.name = @"neat";
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue: @{@"neat": @"rad"}];
        builder.renderedLocale = @{@"some": @"locale"};
        builder.source = UAInAppMessageSourceRemoteData;
    }];
    
    self.scheduleID = [NSUUID UUID].UUIDString;
    self.analytics = [[UATestAnalytics alloc] init];
    self.analytics.conversionSendID = [NSUUID UUID].UUIDString;
    self.analytics.conversionPushMetadata = [NSUUID UUID].UUIDString;
}

/**
 * Test in-app page swipe event.
 */
- (void)testPageSwipeEvent {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"pager_identifier":@"pager_id",
        @"from_page_index": @0,
        @"to_page_index": @5,
    };

    UAInAppReporting *reporting = [UAInAppReporting pageSwipeEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                         pagerID:@"pager_id"
                                                                       fromIndex:0
                                                                         toIndex:5];

    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_page_swipe");
}


/**
 * Test in-app form result event.
 */
- (void)testFormResultEvent {
    NSDictionary *formData = @{
        @"form_data": @"test_data"
    };
    
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"forms": formData
    };

    UAInAppReporting *reporting = [UAInAppReporting formResultEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                         formData: formData];
    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_form_result");
}

/**
 * Test in-app form display event.
 */
- (void)testFormDisplayEvent {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"form_identifier": @"some-form"
    };

    UAInAppReporting *reporting = [UAInAppReporting formDisplayEventWithScheduleID:self.scheduleID
                                                                           message:self.message
                                                                            formID:@"some-form"];
    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_form_display");
}

/**
 * Test in-app button tap event.
 */
- (void)testButtonTapEvent {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"button_identifier": @"some-button"
    };

    UAInAppReporting *reporting = [UAInAppReporting buttonTapEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                          buttonID:@"some-button"];
    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_button_tap");
}

/**
 * Test in-app page view event.
 */
- (void)testPageViewEvent {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"pager_identifier":@"pager_id",
        @"page_index": @0,
        @"page_count": @5,
        @"completed": @YES,
    };

    UAInAppReporting *reporting = [UAInAppReporting pageViewEventWithScheduleID:self.scheduleID
                                                                        message:self.message
                                                                        pagerID:@"pager_id"
                                                                          index:0
                                                                          count:5
                                                                      completed:YES];
    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_page_view");
}

/**
 * Test in-app legacy direct open resolution.
 */
- (void)testLegacyDirectOpenResolution {
    NSDictionary *expectedData = @{
        @"id": self.scheduleID,
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"source": @"urban-airship",
        @"resolution": @{
            @"type": @"direct_open"
        }
    };

    UAInAppReporting *reporting = [UAInAppReporting legacyDirectOpenEventWithScheduleID:self.scheduleID];
    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
}

/**
 * Test in-app legacy replaced resolution.
 */
- (void)testLegacyReplacedResolution {
    NSDictionary *expectedData = @{
        @"id": self.scheduleID,
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"source": @"urban-airship",
        @"resolution": @{
            @"type": @"replaced",
            @"replacement_id": @"replacement id"
        }
    };

    UAInAppReporting *reporting = [UAInAppReporting legacyReplacedEventWithScheduleID:self.scheduleID
                                                                        replacementID:@"replacement id"];
    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
}

/**
 * Test in-app user dismissed resolution.
 */
- (void)testUserDismissedResolution {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"resolution": @{
            @"type": @"user_dismissed",
            @"display_time": @"100.000"
        }
    };

    UAInAppMessageResolution *resolution = [UAInAppMessageResolution userDismissedResolution];
    UAInAppReporting *reporting = [UAInAppReporting resolutionEventWithScheduleID:self.scheduleID
                                                                          message:self.message
                                                                       resolution:resolution
                                                                      displayTime:100.0];
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
}

/**
 * Test in-app user timed out resolution.
 */
- (void)testTimedOutResolution {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"resolution": @{
            @"type": @"timed_out",
            @"display_time": @"100.000"
        }
    };

    UAInAppMessageResolution *resolution = [UAInAppMessageResolution timedOutResolution];
    UAInAppReporting *reporting = [UAInAppReporting resolutionEventWithScheduleID:self.scheduleID
                                                                          message:self.message
                                                                       resolution:resolution
                                                                      displayTime:100.0];
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
}


/**
 * Test in-app button resolution.
 */
- (void)testButtonResolution {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"resolution": @{
            @"type": @"button_click",
            @"button_id": @"button",
            @"button_description": @"Dismiss",
            @"display_time": @"100.000"
        }
    };

    UAInAppMessageButtonInfo *info = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"Dismiss";
        }];
        builder.identifier = @"button";
    }];
    
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution buttonClickResolutionWithButtonInfo:info];
    UAInAppReporting *reporting = [UAInAppReporting resolutionEventWithScheduleID:self.scheduleID
                                                                          message:self.message
                                                                       resolution:resolution
                                                                      displayTime:100.0];
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
}

/**
 * Test in-app message click resolution.
 */
- (void)testMessageClickResolution {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"resolution": @{
            @"type": @"message_click",
            @"display_time": @"100.000"
        }
    };
    
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution messageClickResolution];
    UAInAppReporting *reporting = [UAInAppReporting resolutionEventWithScheduleID:self.scheduleID
                                                                          message:self.message
                                                                       resolution:resolution
                                                                      displayTime:100.0];
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
}

/**
 * Test interrupted reoslution event.
 */
- (void)testInterruptedEvent {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"source": @"urban-airship",
        @"resolution": @{
            @"type": @"user_dismissed",
            @"display_time": @"0.000"
        }
    };

    UAInAppReporting *reporting = [UAInAppReporting interruptedEventWithScheduleID:self.scheduleID
                                                                            source:self.message.source];
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_resolution");
}

/**
 * Test campaigns.
 */
- (void)testCampaings {
    NSDictionary *campaigns = @{ @"campaings": @"some-campaigns" };
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID,
            @"campaigns": campaigns
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship"
    };

    UAInAppReporting *reporting = [UAInAppReporting displayEventWithScheduleID:self.scheduleID message:self.message];
    reporting.campaigns = campaigns;
    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
}

/**
 * Test context.
 */
- (void)testContext {
    NSDictionary *reportingContext = @{ @"some reporting context": @"some reporting value" };
    NSDictionary *layoutState = @{ @"some layout state": @"something" };

    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID,
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"context": @{
            @"reporting_context": reportingContext,
            @"some layout state": @"something"
        }
    };

    UAInAppReporting *reporting = [UAInAppReporting displayEventWithScheduleID:self.scheduleID message:self.message];
    reporting.reportingContext = reportingContext;
    reporting.layoutState = layoutState;
    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
}


@end
