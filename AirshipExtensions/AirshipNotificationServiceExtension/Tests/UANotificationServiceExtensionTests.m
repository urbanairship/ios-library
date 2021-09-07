///* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UANotificationServiceExtension.h"

@interface UANotificationServiceExtensionTests : XCTestCase

@property(nonatomic, strong) UANotificationServiceExtension *serviceExtension;

@end

@implementation UANotificationServiceExtensionTests

- (void)setUp {
    [super setUp];
    
    self.serviceExtension = [[UANotificationServiceExtension alloc] init];
}

- (void)tearDown {
    self.serviceExtension = nil;
    
    [super tearDown];
}

- (void)testEmptyContent {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"identifier" content:content trigger:nil];
    XCTestExpectation *contentDelivered = [self expectationWithDescription:@"content delivered"];
    [self.serviceExtension didReceiveNotificationRequest:request withContentHandler:^(UNNotificationContent * _Nonnull contentToDeliver) {
        XCTAssertEqual(contentToDeliver.attachments.count, 0);
        XCTAssertNil(contentToDeliver.badge);
        XCTAssertNil(contentToDeliver.body);
        XCTAssertNil(contentToDeliver.badge);
        XCTAssertEqualObjects(contentToDeliver.categoryIdentifier, @"");
        XCTAssertEqualObjects(contentToDeliver.launchImageName, @"");
        XCTAssertNil(contentToDeliver.sound);
        XCTAssertNil(contentToDeliver.subtitle);
        XCTAssertEqualObjects(contentToDeliver.threadIdentifier, @"");
        XCTAssertNil(contentToDeliver.title);
        XCTAssertEqual(contentToDeliver.userInfo.count, 0);
        if (@available(iOS 12.0, *)) {
            XCTAssertEqualObjects(contentToDeliver.summaryArgument, @"");
            XCTAssertEqual(contentToDeliver.summaryArgumentCount,0);
        }
        if (@available(iOS 13.0, *)) {
            XCTAssertNil(contentToDeliver.targetContentIdentifier);
        }
        [contentDelivered fulfill];
    }];
    
    [self waitForExpectations:@[contentDelivered] timeout:10];
}

- (void)testSampleContent {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.body = @"oh hi";
    content.categoryIdentifier = @"news";

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[@"_"] = @"a323385b-010a-401c-93ae-936cb58dff04";
    
    NSMutableDictionary *aps = [NSMutableDictionary dictionary];
    aps[@"alert"] = @"oh hi";
    aps[@"category"] = @"news";
    aps[@"mutable-content"] = @YES;
    userInfo[@"aps"] = aps;
    
    NSMutableDictionary *mediaAttachment = [NSMutableDictionary dictionary];
    NSMutableDictionary *mediaContent = [NSMutableDictionary dictionary];
    mediaContent[@"body"] = @"Have you ever seen a moustache like this?!";
    mediaContent[@"subtitle"] = @"The saga of a bendy stache.";
    mediaContent[@"title"] = @"Moustache Twirl";
    mediaAttachment[@"content"] = mediaContent;
    
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    NSMutableDictionary *crop = [NSMutableDictionary dictionary];
    crop[@"height"] = @0.5;
    crop[@"width"] = @0.5;
    crop[@"x"] = @0.25;
    crop[@"y"] = @0.25;
    
    options[@"crop"] = crop;
    options[@"time"] = @15;
    
    mediaAttachment[@"options"] = options;
    
    // Get file system URL for test image
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *mediaURL = [bundle URLForResource:@"airship" withExtension:@"jpg"];
    mediaAttachment[@"url"] = @[ [mediaURL absoluteString] ];

    userInfo[@"com.urbanairship.media_attachment"] = mediaAttachment;
    
    userInfo[@"com.urbanairship.metadata"] = @"eyJ2ZXJzaW9uX2lkIjoxLCJ0aW1lIjoxNTg3NTc2Mzk2NDM1LCJwdXNoX2lkIjoiNmUyNzQ1N2MtZDllNi00MWQ3LWJlZDYtNTAyMTkyNDA0NDI2In0=";
    
    content.userInfo = userInfo;
    
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"4B2D08E6-8955-4964-8C15-6F7FEBC0EBB4" content:content trigger:nil];
    
    XCTestExpectation *contentDelivered = [self expectationWithDescription:@"content delivered"];    
    [self.serviceExtension didReceiveNotificationRequest:request withContentHandler:^(UNNotificationContent * _Nonnull deliveredContent) {
        XCTAssertEqual(deliveredContent.attachments.count, 1);
        if (deliveredContent.attachments.count) {
            UNNotificationAttachment *attachment = (UNNotificationAttachment *)deliveredContent.attachments[0];
            XCTAssertNotNil(attachment.identifier);
            XCTAssertNotNil(attachment.URL);
            XCTAssertTrue([[NSFileManager defaultManager] contentsEqualAtPath:attachment.URL.path andPath:mediaURL.path]);
            XCTAssertEqualObjects(attachment.type, @"public.jpeg");
        }
        XCTAssertNil(deliveredContent.badge);
        XCTAssertEqualObjects(deliveredContent.body, mediaContent[@"body"]);
        XCTAssertEqualObjects(deliveredContent.categoryIdentifier, @"news");
        XCTAssertEqualObjects(deliveredContent.launchImageName, @"");
        XCTAssertNil(deliveredContent.sound);
        XCTAssertEqualObjects(deliveredContent.subtitle, mediaContent[@"subtitle"]);
        XCTAssertEqualObjects(deliveredContent.threadIdentifier, @"");
        XCTAssertEqualObjects(deliveredContent.title, mediaContent[@"title"]);
        XCTAssertEqualObjects(deliveredContent.userInfo, userInfo);
        if (@available(iOS 12.0, *)) {
            XCTAssertEqualObjects(deliveredContent.summaryArgument, @"");
            XCTAssertEqual(deliveredContent.summaryArgumentCount,0);
        }
        if (@available(iOS 13.0, *)) {
            XCTAssertNil(deliveredContent.targetContentIdentifier);
        }
        [contentDelivered fulfill];
    }];
    
    [self waitForExpectations:@[contentDelivered] timeout:10];
}

@end
