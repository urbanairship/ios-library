/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessagePageSwipeEvent+Internal.h"
#import "UAInAppMessageButtonTapEvent+Internal.h"
#import "UAInAppMessagePageViewEvent+Internal.h"
#import "UAInAppMessageFormDisplayEvent+Internal.h"
#import "UAInAppMessageFormResultEvent+Internal.h"
#import "UAInAppMessageCustomDisplayContent+Internal.h"
#import "AirshipTests-Swift.h"

@interface UAInAppMessageEventTest : XCTestCase
@property(nonatomic, strong) UATestAnalytics *analytics;
@property(nonatomic, strong) UATestAirshipInstance *airship;
@end

@implementation UAInAppMessageEventTest

- (void)setUp {
    [super setUp];

    self.analytics = [[UATestAnalytics alloc] init];
    self.analytics.conversionSendID = [NSUUID UUID].UUIDString;
    self.analytics.conversionPushMetadata = [NSUUID UUID].UUIDString;
    self.airship = [[UATestAirshipInstance alloc] init];
    self.airship.components = @[self.analytics];
    [self.airship makeShared];
}

/**
 * Test in-app page swipe event.
 */
- (void)testPageSwipeEvent {
    NSDictionary *expectedData = @{ @"id": @{ @"message_id": @"message_id"},
                                    @"conversion_send_id": self.analytics.conversionSendID,
                                    @"conversion_metadata": self.analytics.conversionPushMetadata,
                                    @"source": @"app-defined",
                                    @"pager_identifier":@"pager_id",
                                    @"from_page_index": @0,
                                    @"to_page_index": @5,
                                    @"context": @{@"identifier":@"id",
                                    }
                                    
                                     
    };


    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];
    
    NSDictionary *context = @{@"identifier":@"id"};
    NSDictionary *campaigns = @{@"campaign_info":@"info"};
    
    UAInAppMessagePageSwipeEvent *event = [UAInAppMessagePageSwipeEvent eventWithMessage:message messageID:@"message_id" pagerIdentifier:@"pager_id" fromIndex:0 toIndex:5 reportingContext:context campaigns:campaigns];
    XCTAssertEqualObjects(event.data, expectedData);
}

/**
 * Test in-app form result event.
 */
- (void)testFormResultEvent {    
    NSDictionary *expectedData = @{ @"id": @{ @"message_id": @"message_id"},
                                    @"conversion_send_id": self.analytics.conversionSendID,
                                    @"conversion_metadata": self.analytics.conversionPushMetadata,
                                    @"source": @"app-defined",
                                    @"form_identifier":@"form_id",
                                    @"forms": @{@"form_data":@"test_data"},
                                    @"context": @{@"identifier":@"id"},
    };


    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];
    
    NSDictionary *campaigns = @{@"campaign_info":@"info"};
    
    UAInAppMessageFormResultEvent *event = [UAInAppMessageFormResultEvent eventWithMessage:message messageID:@"message_id" formIdentifier:@"form_id" formData:@{@"form_data":@"test_data"} reportingContext:@{@"identifier":@"id"} campaigns:campaigns];
    XCTAssertEqualObjects(event.data, expectedData);
}

/**
 * Test in-app form display event.
 */
- (void)testFormDisplayEvent {
    NSDictionary *expectedData = @{ @"id": @{ @"message_id": @"message_id"},
                                    @"conversion_send_id": self.analytics.conversionSendID,
                                    @"conversion_metadata": self.analytics.conversionPushMetadata,
                                    @"source": @"app-defined",
                                    @"form_identifier":@"form_id",
                                    @"context": @{@"identifier":@"id"},
    };


    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];
    
    NSDictionary *campaigns = @{@"campaign_info":@"info"};
    NSDictionary *context = @{@"identifier":@"id"};
    UAInAppMessageFormDisplayEvent *event = [UAInAppMessageFormDisplayEvent eventWithMessage:message messageID:@"message_id" formIdentifier:@"form_id" reportingContext:context campaigns:campaigns];
    XCTAssertEqualObjects(event.data, expectedData);
}

/**
 * Test in-app button tap event.
 */
- (void)testButtonTapEvent {
    NSDictionary *expectedData = @{ @"id": @{ @"message_id": @"message_id"},
                                    @"conversion_send_id": self.analytics.conversionSendID,
                                    @"conversion_metadata": self.analytics.conversionPushMetadata,
                                    @"source": @"app-defined",
                                    @"button_identifier":@"button_id",
                                    @"context": @{@"identifier":@"id"},
    };


    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];
    
    NSDictionary *context = @{@"identifier":@"id"};
    NSDictionary *campaigns = @{@"campaign_info":@"info"};
    UAInAppMessageButtonTapEvent *event = [UAInAppMessageButtonTapEvent eventWithMessage:message messageID:@"message_id" buttonIdentifier:@"button_id" reportingContext:context campaigns:campaigns];
    XCTAssertEqualObjects(event.data, expectedData);
}

/**
 * Test in-app page view event.
 */
- (void)testPageViewEvent {
    NSDictionary *expectedData = @{ @"id": @{ @"message_id": @"message_id"},
                                    @"conversion_send_id": self.analytics.conversionSendID,
                                    @"conversion_metadata": self.analytics.conversionPushMetadata,
                                    @"source": @"app-defined",
                                    @"pager_identifier":@"pager_id",
                                    @"page_index": @0,
                                    @"page_count": @5,
                                    @"completed": @YES,
                                    @"context": @{@"identifier":@"id"},
    };


    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{}];
    }];
    
    NSDictionary *campaigns = @{@"campaign_info":@"info"};
    NSDictionary *context = @{@"identifier":@"id"};
    UAInAppMessagePageViewEvent *event = [UAInAppMessagePageViewEvent eventWithMessage:message messageID:@"message_id" pagerIdentifier:@"pager_id" pageIndex:0 pageCount:5 completed:YES reportingContext:context campaigns:campaigns];
    XCTAssertEqualObjects(event.data, expectedData);
}

@end
