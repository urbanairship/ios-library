/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAMediaAttachmentPayload.h"
#import <UserNotifications/UserNotifications.h>

#define kUAAccengageNotificationAttachmentServiceURLKey @"att-url"
#define kUAAccengageNotificationAttachmentServiceURLIdKey @"att-id"
#define kUAAccengageNotificationAttachmentServiceURLSKey @"acc-atts"
#define kUAAccengageNotificationIDKey @"a4sid"

#define kUANotificationAttachmentServiceURLKey @"url"
#define kUANotificationAttachmentServiceURLIdKey @"url_id"
#define kUANotificationAttachmentServiceURLSKey @"urls"
#define kUANotificationAttachmentServiceThumbnailKey @"thumbnail_id"
#define kUANotificationAttachmentServiceOptionsKey @"options"
#define kUANotificationAttachmentServiceCropKey @"crop"
#define kUANotificationAttachmentServiceTimeKey @"time"
#define kUANotificationAttachmentServiceHiddenKey @"hidden"
#define kUANotificationAttachmentServiceContentKey @"content"
#define kUANotificationAttachmentServiceBodyKey @"body"
#define kUANotificationAttachmentServiceTitleKey @"title"
#define kUANotificationAttachmentServiceSubtitleKey @"subtitle"

@interface UAMediaAttachmentPayloadTests : UABaseTest
@end

@implementation UAMediaAttachmentPayloadTests

- (void)testNilPayload {
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:nil];
    XCTAssertNil(parsedPayload);
}

- (void)testAirshipEmptyPayload {
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:@{}];
    XCTAssertNil(parsedPayload);
}

- (void)testAccengageEmptyPayload {
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:@{ kUAAccengageNotificationIDKey : @"fake-accengage-id"}];
    XCTAssertNil(parsedPayload);
}

- (void)testAirshipURLPayloads {
    NSMutableDictionary *testPayload;
    UAMediaAttachmentPayload *parsedPayload;
    NSArray *urlArray;
    
    // NOT VALID PAYLOADS
    testPayload = [NSMutableDictionary dictionary];
    testPayload[kUANotificationAttachmentServiceURLKey] = @{};
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // Test valid contents of the url when it is an empty array
    testPayload = [NSMutableDictionary dictionary];
    testPayload[kUANotificationAttachmentServiceURLKey] = @[];

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 0);

    // Airship payload
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 0);

    // VALID PAYLOADS
    testPayload = [NSMutableDictionary dictionary];
    testPayload[kUANotificationAttachmentServiceURLKey] = @"https://sample.url";
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 1);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)(parsedPayload.urls)[0]).url.absoluteString, testPayload[kUANotificationAttachmentServiceURLKey]);

    // Test contents of the url when it is an array with valid urls
    testPayload = [NSMutableDictionary dictionary];
    urlArray = @[ @"http://sample1.url", @"http://sample1.url" ];
    testPayload[kUANotificationAttachmentServiceURLKey] = urlArray;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 2);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[0]).url.absoluteString, urlArray[0]);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[1]).url.absoluteString, urlArray[1]);
}

- (void)testAccengageURLPayloads {
    NSMutableDictionary *testPayload;
    UAMediaAttachmentPayload *parsedPayload;
    
    // NOT VALID PAYLOADS
    testPayload = [NSMutableDictionary dictionaryWithDictionary:@{ kUAAccengageNotificationIDKey : @"fake-accengage-id"}];
    testPayload[kUANotificationAttachmentServiceURLKey] = @{};
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);
}

- (void)testAirshipURLSPayloads {
    NSMutableDictionary *testPayload;
    UAMediaAttachmentPayload *parsedPayload;
    NSMutableArray *urlArray;

    // NOT VALID PAYLOADS
    // URLS has to be an NSArray
    testPayload = [NSMutableDictionary dictionary];
    testPayload[kUANotificationAttachmentServiceURLSKey] = @{};

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // Test contents of the url when it is an array with invalid urls
    testPayload = [NSMutableDictionary dictionary];
    testPayload[kUANotificationAttachmentServiceURLSKey] = @[ @1 ];

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 0);

    // VALID PAYLOADS
    // "url" key is ignored if "urls" is present
    testPayload = [self minimalValidAirshipPayload];
    testPayload[kUANotificationAttachmentServiceURLSKey] = @[ ];
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 0);
    
    // Test contents of the url when it is an array with valid urls
    testPayload = [self minimalValidAirshipPayload];
    urlArray = [NSMutableArray array];
    [urlArray addObject:@{ kUANotificationAttachmentServiceURLKey : @"http://sample1.url", kUANotificationAttachmentServiceURLIdKey : @"sample-1-id" }];
    [urlArray addObject:@{ kUANotificationAttachmentServiceURLKey : @"http://sample2.url", kUANotificationAttachmentServiceURLIdKey : @"sample-2-id" }];
    testPayload[kUANotificationAttachmentServiceURLSKey] = urlArray;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 2);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[0]).url.absoluteString, ((NSDictionary *)urlArray[0])[kUANotificationAttachmentServiceURLKey]);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[1]).url.absoluteString, ((NSDictionary *)urlArray[1])[kUANotificationAttachmentServiceURLKey]);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[0]).urlID, ((NSDictionary *)urlArray[0])[kUANotificationAttachmentServiceURLIdKey]);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[1]).urlID, ((NSDictionary *)urlArray[1])[kUANotificationAttachmentServiceURLIdKey]);
}

- (void)testAccengageURLSPayloads {
    NSMutableDictionary *testPayload;
    UAMediaAttachmentPayload *parsedPayload;
    NSMutableArray *urlArray;

    // NOT VALID PAYLOADS
    // URLS has to be an NSArray
    testPayload = [NSMutableDictionary dictionaryWithDictionary:@{ kUAAccengageNotificationIDKey : @"fake-accengage-id"}];
    testPayload[kUAAccengageNotificationAttachmentServiceURLSKey] = @{};

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);
    
    // Test contents of the url when it is an array with invalid urls
    testPayload = [NSMutableDictionary dictionaryWithDictionary:@{ kUAAccengageNotificationIDKey : @"fake-accengage-id"}];
    testPayload[kUAAccengageNotificationAttachmentServiceURLSKey] = @[ @1 ];

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 0);

    // VALID PAYLOADS
    testPayload = [NSMutableDictionary dictionaryWithDictionary:@{ kUAAccengageNotificationIDKey : @"fake-accengage-id"}];
    testPayload[kUAAccengageNotificationAttachmentServiceURLSKey] = @[ ];

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 0);

    // Test contents of the url when it is an array with valid urls
    testPayload = [NSMutableDictionary dictionaryWithDictionary:@{ kUAAccengageNotificationIDKey : @"fake-accengage-id"}];
    urlArray = [NSMutableArray array];
    [urlArray addObject:@{ kUAAccengageNotificationAttachmentServiceURLKey : @"http://sample1.url", kUAAccengageNotificationAttachmentServiceURLIdKey : @"sample-1-id" }];
    [urlArray addObject:@{ kUAAccengageNotificationAttachmentServiceURLKey : @"http://sample2.url", kUAAccengageNotificationAttachmentServiceURLIdKey : @"sample-2-id" }];
    testPayload[kUAAccengageNotificationAttachmentServiceURLSKey] = urlArray;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.urls.count, 2);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[0]).url.absoluteString, ((NSDictionary *)urlArray[0])[kUAAccengageNotificationAttachmentServiceURLKey]);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[1]).url.absoluteString, ((NSDictionary *)urlArray[1])[kUAAccengageNotificationAttachmentServiceURLKey]);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[0]).urlID, ((NSDictionary *)urlArray[0])[kUAAccengageNotificationAttachmentServiceURLIdKey]);
    XCTAssertEqualObjects(((UAMediaAttachmentURL *)parsedPayload.urls[1]).urlID, ((NSDictionary *)urlArray[1])[kUAAccengageNotificationAttachmentServiceURLIdKey]);
}

- (void)testAirshipOptionsPayloads {
    NSMutableDictionary *testPayload;
    
    // NOT VALID PAYLOADS
    
    // Options has to be an NSDictionary
    testPayload = [self minimalValidAirshipPayload];
    testPayload[kUANotificationAttachmentServiceOptionsKey] = [NSArray array];
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    
    // Empty options dictionary
    testPayload = [self minimalValidAirshipPayload];
    testPayload[kUANotificationAttachmentServiceOptionsKey] = [NSMutableDictionary dictionary];

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertEqual(parsedPayload.options.count, 0);
}

- (void)testAccengageOptionsPayloads {
    NSMutableDictionary *testPayload;
    UAMediaAttachmentPayload *parsedPayload;

    // NOT VALID PAYLOADS
    
    // Options has to be an NSDictionary
    testPayload = [self minimalValidAccengagePayload];
    testPayload[kUANotificationAttachmentServiceOptionsKey] = [NSArray array];
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);
    
}

- (void)testAirshipCropOptionsPayloads {
    NSMutableDictionary *testPayload;
    
    // NOT VALID PAYLOADS

    // Crop dictionary is not a dictionary
    testPayload = [self minimalValidAirshipPayload];
    NSMutableDictionary<NSString *, id> *serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = @"";
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // Empty crop dictionary
    testPayload = [self minimalValidAirshipPayload];
    serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = [NSMutableDictionary dictionary];
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // Missing crop option
    testPayload = [self minimalValidAirshipPayload];
    NSMutableDictionary<NSString *, id> *cropOptions = [NSMutableDictionary dictionary];
    cropOptions[@"y"] = @0.0;
    cropOptions[@"width"] = @0.5;
    cropOptions[@"height"] = @1.0;
    serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = cropOptions;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // Non-valid crop option
    testPayload = [self minimalValidAirshipPayload];
    cropOptions = [NSMutableDictionary dictionary];
    cropOptions[@"y"] = @0.0;
    cropOptions[@"width"] = @0.5;
    cropOptions[@"height"] = @1.0;
    cropOptions[@"x"] = @10.0;
    serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = cropOptions;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    
    // valid crop options
    testPayload = [self minimalValidAirshipPayload];
    cropOptions = [NSMutableDictionary dictionary];
    cropOptions[@"x"] = @1.0;
    cropOptions[@"y"] = @1.0;
    cropOptions[@"width"] = @0.5;
    cropOptions[@"height"] = @1.0;
    serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = cropOptions;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    // Airship payload
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    NSDictionary<NSString *, id> *parsedServiceOptions = parsedPayload.options;
    XCTAssertNotNil(parsedServiceOptions);
    XCTAssertEqual(parsedServiceOptions.count, 1);
    NSDictionary<NSString *, id> *parsedCropOptions = parsedServiceOptions[UNNotificationAttachmentOptionsThumbnailClippingRectKey];
    XCTAssertNotNil(parsedCropOptions);
    XCTAssertEqual(parsedCropOptions[@"X"], cropOptions[@"x"]);
    XCTAssertEqual(parsedCropOptions[@"Y"], cropOptions[@"y"]);
    XCTAssertEqual(parsedCropOptions[@"Width"], cropOptions[@"width"]);
    XCTAssertEqual(parsedCropOptions[@"Height"], cropOptions[@"height"]);
}

- (void)testAccengageCropOptionsPayloads {
    NSMutableDictionary *testPayload;
    
    // NOT VALID PAYLOADS

    // Crop dictionary is not a dictionary
    testPayload = [self minimalValidAccengagePayload];
    NSMutableDictionary<NSString *, id> *serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = @"";
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // Empty crop dictionary
    testPayload = [self minimalValidAccengagePayload];
    serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = [NSMutableDictionary dictionary];
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // Missing crop option
    testPayload = [self minimalValidAccengagePayload];
    NSMutableDictionary<NSString *, id> *cropOptions = [NSMutableDictionary dictionary];
    cropOptions[@"y"] = @0.0;
    cropOptions[@"width"] = @0.5;
    cropOptions[@"height"] = @1.0;
    serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = cropOptions;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // Non-valid crop option
    testPayload = [self minimalValidAccengagePayload];
    cropOptions = [NSMutableDictionary dictionary];
    cropOptions[@"y"] = @0.0;
    cropOptions[@"width"] = @0.5;
    cropOptions[@"height"] = @1.0;
    cropOptions[@"x"] = @10.0;
    serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = cropOptions;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    // Airship payload
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    
    // valid crop options
    testPayload = [self minimalValidAccengagePayload];
    cropOptions = [NSMutableDictionary dictionary];
    cropOptions[@"x"] = @1.0;
    cropOptions[@"y"] = @1.0;
    cropOptions[@"width"] = @0.5;
    cropOptions[@"height"] = @1.0;
    serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceCropKey] = cropOptions;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    NSDictionary<NSString *, id> *parsedServiceOptions = parsedPayload.options;
    XCTAssertNotNil(parsedServiceOptions);
    XCTAssertEqual(parsedServiceOptions.count, 1);
    NSDictionary<NSString *, id> *parsedCropOptions = parsedServiceOptions[UNNotificationAttachmentOptionsThumbnailClippingRectKey];
    XCTAssertNotNil(parsedCropOptions);
    XCTAssertEqual(parsedCropOptions[@"X"], cropOptions[@"x"]);
    XCTAssertEqual(parsedCropOptions[@"Y"], cropOptions[@"y"]);
    XCTAssertEqual(parsedCropOptions[@"Width"], cropOptions[@"width"]);
    XCTAssertEqual(parsedCropOptions[@"Height"], cropOptions[@"height"]);
}

- (void)testAirshipTimeOptionPayloads {
    NSMutableDictionary *testPayload;
    
    // NOT VALID PAYLOADS

    // Not valid time option
    testPayload = [self minimalValidAirshipPayload];
    NSMutableDictionary *serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceTimeKey] = @"";
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    testPayload = [self minimalValidAirshipPayload];
    serviceOptions[kUANotificationAttachmentServiceTimeKey] = @1;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    // Airship payload
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    NSDictionary<NSString *, id> *parsedServiceOptions = parsedPayload.options;
    XCTAssertNotNil(parsedServiceOptions);
    XCTAssertEqual(parsedServiceOptions.count, 1);
    XCTAssertEqual(parsedServiceOptions[@"thumbnailTime"], serviceOptions[kUANotificationAttachmentServiceTimeKey]);
}

- (void)testAccengageTimeOptionPayloads {
    NSMutableDictionary *testPayload;
    
    // NOT VALID PAYLOADS

    // Not valid time option
    testPayload = [self minimalValidAccengagePayload];
    NSMutableDictionary *serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceTimeKey] = @"";
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    testPayload = [self minimalValidAccengagePayload];
    serviceOptions[kUANotificationAttachmentServiceTimeKey] = @1;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    NSDictionary<NSString *, id> *parsedServiceOptions = parsedPayload.options;
    XCTAssertNotNil(parsedServiceOptions);
    XCTAssertEqual(parsedServiceOptions.count, 1);
    XCTAssertEqual(parsedServiceOptions[@"thumbnailTime"], serviceOptions[kUANotificationAttachmentServiceTimeKey]);
}

- (void)testAirshipHiddenOptionPayloads {
    NSMutableDictionary *testPayload;
    
    // NOT VALID PAYLOADS

    // Not valid hidden option
    testPayload = [self minimalValidAirshipPayload];
    NSMutableDictionary *serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceHiddenKey] = @"";
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    testPayload = [self minimalValidAirshipPayload];
    serviceOptions[kUANotificationAttachmentServiceHiddenKey] = @YES;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    NSDictionary<NSString *, id> *parsedServiceOptions = parsedPayload.options;
    XCTAssertNotNil(parsedServiceOptions);
    XCTAssertEqual(parsedServiceOptions.count, 1);
    XCTAssertEqual(parsedServiceOptions[@"thumbnailHidden"], serviceOptions[kUANotificationAttachmentServiceHiddenKey]);
}

- (void)testAccengageHiddenOptionPayloads {
    NSMutableDictionary *testPayload;
    
    // NOT VALID PAYLOADS

    // Not valid hidden option
    testPayload = [self minimalValidAccengagePayload];
    NSMutableDictionary *serviceOptions = [NSMutableDictionary dictionary];
    serviceOptions[kUANotificationAttachmentServiceHiddenKey] = @"";
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    testPayload = [self minimalValidAccengagePayload];
    serviceOptions[kUANotificationAttachmentServiceHiddenKey] = @YES;
    testPayload[kUANotificationAttachmentServiceOptionsKey] = serviceOptions;

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    NSDictionary<NSString *, id> *parsedServiceOptions = parsedPayload.options;
    XCTAssertNotNil(parsedServiceOptions);
    XCTAssertEqual(parsedServiceOptions.count, 1);
    XCTAssertEqual(parsedServiceOptions[@"thumbnailHidden"], serviceOptions[kUANotificationAttachmentServiceHiddenKey]);
}

- (void)testAirshipContentPayloads {
    NSMutableDictionary<NSString *, id> *content;
    NSMutableDictionary *testPayload;

    // NOT VALID PAYLOADS
    testPayload = [self minimalValidAirshipPayload];
    testPayload[kUANotificationAttachmentServiceContentKey] = @"";
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // non-valid content
    testPayload = [self minimalValidAirshipPayload];
    content = [NSMutableDictionary dictionaryWithDictionary:@{ kUANotificationAttachmentServiceBodyKey : [NSDictionary dictionary] }];
    testPayload[kUANotificationAttachmentServiceContentKey] = content;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    
    // empty content
    testPayload = [self minimalValidAirshipPayload];
    content = [NSMutableDictionary dictionary];
    testPayload[kUANotificationAttachmentServiceContentKey] = content;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertNotNil(parsedPayload.content);
    XCTAssertNil(parsedPayload.content.title);
    XCTAssertNil(parsedPayload.content.subtitle);
    XCTAssertNil(parsedPayload.content.body);

    // minimal content
    testPayload = [self minimalValidAirshipPayload];
    content = [NSMutableDictionary dictionary];
    content[kUANotificationAttachmentServiceTitleKey] = @"A Title";
    testPayload[kUANotificationAttachmentServiceContentKey] = content;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertNotNil(parsedPayload.content);
    XCTAssertEqual(parsedPayload.content.title, content[kUANotificationAttachmentServiceTitleKey]);
    XCTAssertEqual(parsedPayload.content.subtitle, content[kUANotificationAttachmentServiceSubtitleKey]);
    XCTAssertEqual(parsedPayload.content.body, content[kUANotificationAttachmentServiceBodyKey]);
    
    // complete content
    testPayload = [self minimalValidAirshipPayload];
    content = [NSMutableDictionary dictionary];
    content[kUANotificationAttachmentServiceTitleKey] = @"A Title";
    content[kUANotificationAttachmentServiceSubtitleKey] = @"A subtitle";
    content[kUANotificationAttachmentServiceBodyKey] = @"A body";

    testPayload[kUANotificationAttachmentServiceContentKey] = content;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertNotNil(parsedPayload.content);
    XCTAssertEqual(parsedPayload.content.title, content[kUANotificationAttachmentServiceTitleKey]);
    XCTAssertEqual(parsedPayload.content.subtitle, content[kUANotificationAttachmentServiceSubtitleKey]);
    XCTAssertEqual(parsedPayload.content.body, content[kUANotificationAttachmentServiceBodyKey]);

}

- (void)testAccengageContentPayloads {
    NSMutableDictionary<NSString *, id> *content;
    NSMutableDictionary *testPayload;

    // NOT VALID PAYLOADS
    testPayload = [self minimalValidAccengagePayload];
    testPayload[kUANotificationAttachmentServiceContentKey] = @"";
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // non-valid content
    testPayload = [self minimalValidAccengagePayload];
    content = [NSMutableDictionary dictionaryWithDictionary:@{ kUANotificationAttachmentServiceBodyKey : [NSDictionary dictionary] }];
    testPayload[kUANotificationAttachmentServiceContentKey] = content;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    
    // empty content
    testPayload = [self minimalValidAccengagePayload];
    content = [NSMutableDictionary dictionary];
    testPayload[kUANotificationAttachmentServiceContentKey] = content;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertNotNil(parsedPayload.content);
    XCTAssertNil(parsedPayload.content.title);
    XCTAssertNil(parsedPayload.content.subtitle);
    XCTAssertNil(parsedPayload.content.body);

    // minimal content
    testPayload = [self minimalValidAccengagePayload];
    content = [NSMutableDictionary dictionary];
    content[kUANotificationAttachmentServiceTitleKey] = @"A Title";
    testPayload[kUANotificationAttachmentServiceContentKey] = content;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertNotNil(parsedPayload.content);
    XCTAssertEqual(parsedPayload.content.title, content[kUANotificationAttachmentServiceTitleKey]);
    XCTAssertEqual(parsedPayload.content.subtitle, content[kUANotificationAttachmentServiceSubtitleKey]);
    XCTAssertEqual(parsedPayload.content.body, content[kUANotificationAttachmentServiceBodyKey]);
    
    // complete content
    testPayload = [self minimalValidAccengagePayload];
    content = [NSMutableDictionary dictionary];
    content[kUANotificationAttachmentServiceTitleKey] = @"A Title";
    content[kUANotificationAttachmentServiceSubtitleKey] = @"A subtitle";
    content[kUANotificationAttachmentServiceBodyKey] = @"A body";

    testPayload[kUANotificationAttachmentServiceContentKey] = content;
    
    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
    XCTAssertNotNil(parsedPayload.content);
    XCTAssertEqual(parsedPayload.content.title, content[kUANotificationAttachmentServiceTitleKey]);
    XCTAssertEqual(parsedPayload.content.subtitle, content[kUANotificationAttachmentServiceSubtitleKey]);
    XCTAssertEqual(parsedPayload.content.body, content[kUANotificationAttachmentServiceBodyKey]);
}

- (void)testAirshipThumbnailIDPayloads {
    NSMutableDictionary *testPayload;

    // NOT VALID PAYLOADS
    
    // non-valid thumbnail URL
    testPayload = [self minimalValidAirshipPayload];
    testPayload[kUANotificationAttachmentServiceThumbnailKey] = @1;
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    
    // empty content
    testPayload = [self minimalValidAirshipPayload];
    testPayload[kUANotificationAttachmentServiceThumbnailKey] = @"sample-thumbnail-id";

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
}

- (void)testAccengageThumbnailIDPayloads {
    NSMutableDictionary *testPayload;

    // NOT VALID PAYLOADS
    
    // non-valid thumbnail URL
    testPayload = [self minimalValidAccengagePayload];
    testPayload[kUANotificationAttachmentServiceThumbnailKey] = @1;
    
    UAMediaAttachmentPayload *parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNil(parsedPayload);

    // VALID PAYLOADS
    
    // empty content
    testPayload = [self minimalValidAccengagePayload];
    testPayload[kUANotificationAttachmentServiceThumbnailKey] = @"sample-thumbnail-id";

    parsedPayload = [UAMediaAttachmentPayload payloadWithJSONObject:testPayload];
    XCTAssertNotNil(parsedPayload);
}

#pragma mark -
#pragma mark Test Utilities

- (NSMutableDictionary *)minimalValidAirshipPayload {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    
    payload[kUANotificationAttachmentServiceURLKey] = @"https://sample.url";
    
    return payload;
}

- (NSMutableDictionary *)minimalValidAccengagePayload {
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{ kUAAccengageNotificationIDKey : @"fake-accengage-id"}];
    
    payload[kUAAccengageNotificationAttachmentServiceURLSKey] = @[ @{ kUANotificationAttachmentServiceURLKey : @"https://sample.url" } ];
    
    return payload;
}

@end
