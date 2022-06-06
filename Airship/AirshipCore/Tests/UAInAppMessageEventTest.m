/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "AirshipTests-Swift.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageCustomDisplayContent.h"
#import "UAInAPpReporting+Internal.h"
@import AirshipCore;

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
        @"from_page_identifier": @"page0",
        @"to_page_identifier": @"page5"
    };
    
    UAThomasPagerInfo *from = [[UAThomasPagerInfo alloc] initWithIdentifier:@"pager_id"
                                                                  pageIndex:0
                                                             pageIdentifier:@"page0"
                                                                  pageCount:5
                                                                  completed:false];
    
    UAThomasPagerInfo *to = [[UAThomasPagerInfo alloc] initWithIdentifier:@"pager_id"
                                                                  pageIndex:5
                                                             pageIdentifier:@"page5"
                                                                  pageCount:5
                                                                  completed:true];
    
    UAInAppReporting *reporting = [UAInAppReporting pageSwipeEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                            from:from
                                                                              to:to];
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_page_swipe");
}

/**
 * Test in-app pager summary event.
 */
- (void)testPagerSummaryEvent {
    NSArray *pages = @[
        @{
            @"page_index": @0,
            @"page_identifier": @"page0",
            @"duration": @"10.1"
        },
        @{
            @"page_index": @1,
            @"page_identifier": @"page1",
            @"duration": @"3.1"
        },
    ];
    
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"pager_identifier":@"pager_id",
        @"viewed_pages": pages,
        @"page_count": @5,
        @"completed": @(NO)
    };
    
    UAThomasPagerInfo *pagerInfo = [[UAThomasPagerInfo alloc] initWithIdentifier:@"pager_id"
                                                                  pageIndex:1
                                                             pageIdentifier:@"page1"
                                                                  pageCount:5
                                                                  completed:NO];
    


    UAInAppReporting *reporting = [UAInAppReporting pagerSummaryEventWithScehduleID:self.scheduleID
                                                                            message:self.message
                                                                          pagerInfo:pagerInfo
                                                                        viewedPages:pages];
                                                                              
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_pager_summary");
}

/**
 * Test in-app pager completed event.
 */
- (void)testPagerCompletedEvent {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"pager_identifier": @"pager_id",
        @"page_count": @5,
        @"page_index": @4,
        @"page_identifier": @"page4id"
    };

    
    UAThomasPagerInfo *pagerInfo = [[UAThomasPagerInfo alloc] initWithIdentifier:@"pager_id"
                                                                  pageIndex:4
                                                             pageIdentifier:@"page4id"
                                                                  pageCount:5
                                                                  completed:YES];
    
    
    UAInAppReporting *reporting = [UAInAppReporting pagerCompletedEventWithScheduleID:self.scheduleID
                                                                              message:self.message
                                                                            pagerInfo:pagerInfo];
    
    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];
    
    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_pager_completed");
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
    
    UAThomasFormResult *formResult = [[UAThomasFormResult alloc] initWithIdentifier:@"form_id" formData:formData];

    UAInAppReporting *reporting = [UAInAppReporting formResultEventWithScheduleID:self.scheduleID
                                                                          message:self.message
                                                                        formResult:formResult];
    
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
        @"form_identifier": @"some-form",
        @"form_response_type": @"some form response type",
        @"form_type": @"some form type"
    };

    UAThomasFormInfo *formInfo = [[UAThomasFormInfo alloc] initWithIdentifier:@"some-form"
                                                                    submitted:NO
                                                                     formType:@"some form type"
                                                               formResponseType:@"some form response type"];

    
    UAInAppReporting *reporting = [UAInAppReporting formDisplayEventWithScheduleID:self.scheduleID
                                                                           message:self.message
                                                                          formInfo:formInfo];
    
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
        @"page_identifier": @"page-0",
        @"page_count": @5,
        @"completed": @YES,
        @"viewed_count": @4
    };
    
    UAThomasPagerInfo *pagerInfo = [[UAThomasPagerInfo alloc] initWithIdentifier:@"pager_id"
                                                                  pageIndex:0
                                                             pageIdentifier:@"page-0"
                                                                  pageCount:5
                                                                  completed:YES];

    UAInAppReporting *reporting = [UAInAppReporting pageViewEventWithScheduleID:self.scheduleID
                                                                        message:self.message
                                                                      pagerInfo:pagerInfo
                                                                      viewCount:4];
    
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

- (void)testPermissionResultEvent {
    NSDictionary *expectedData = @{
        @"id": @{
            @"message_id": self.scheduleID
        },
        @"conversion_send_id": self.analytics.conversionSendID,
        @"conversion_metadata": self.analytics.conversionPushMetadata,
        @"locale": self.message.renderedLocale,
        @"source": @"urban-airship",
        @"permission": @"post_notifications",
        @"starting_permission_status": @"denied",
        @"ending_permission_status": @"granted"
    };

    UAInAppReporting *reporting = [UAInAppReporting permissionResultEventWithScheduleID:self.scheduleID
                                                                                message:self.message
                                                                             permission:@"post_notifications"
                                                                         startingStatus:@"denied"
                                                                           endingStatus:@"granted"];

    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];

    XCTAssertEqualObjects(event.data, expectedData);
    XCTAssertEqualObjects(event.eventType, @"in_app_permission_result");
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
            @"pager": @{
                @"identifier": @"pager_id",
                @"page_index": @1,
                @"page_identifier": @"page1",
                @"completed": @NO,
                @"count": @5
            },
            @"form": @{
                @"identifier": @"some-form",
                @"submitted": @YES,
                @"type": @"some form type",
                @"response_type": @"some form response type"
            },
            @"button": @{
                @"identifier": @"some-button",
            }
        }
    };


    UAThomasFormInfo *formInfo = [[UAThomasFormInfo alloc] initWithIdentifier:@"some-form"
                                                                    submitted:YES
                                                                     formType:@"some form type"
                                                               formResponseType:@"some form response type"];

    UAThomasPagerInfo *pagerInfo = [[UAThomasPagerInfo alloc] initWithIdentifier:@"pager_id"
                                                                  pageIndex:1
                                                             pageIdentifier:@"page1"
                                                                  pageCount:5
                                                                  completed:NO];

    UAThomasButtonInfo *buttonInfo = [[UAThomasButtonInfo alloc] initWithIdentifier:@"some-button"];
    
    UAThomasLayoutContext *layoutContext = [[UAThomasLayoutContext alloc] initWithFormInfo:formInfo
                                                                                 pagerInfo:pagerInfo
                                                                                buttonInfo:buttonInfo];
    
    UAInAppReporting *reporting = [UAInAppReporting displayEventWithScheduleID:self.scheduleID message:self.message];
    reporting.reportingContext = reportingContext;
    reporting.layoutContext = layoutContext;

    [reporting record:self.analytics];
    id<UAEvent> event = self.analytics.events[0];

    XCTAssertEqualObjects(event.data, expectedData);
}


@end
