//
//  UANotificationTest.m
//  AirshipLib
//
//  Created by David Crow on 8/9/16.
//
//

#import <XCTest/XCTest.h>
#import "UANotificationContent.h"

@interface UANotificationContentTest : XCTestCase

@property (nonatomic, strong) NSDictionary *notification;
@property (nonatomic, strong) NSDictionary *notificationWithBody;
@property (nonatomic, strong) NSString *testKey;
@property (nonatomic, strong) NSString *testValue;

@end

@implementation UANotificationContentTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

    self.testKey = nil;
    self.testValue = nil;
    self.notification = @{
                          @"aps": @{
                                  @"alert": @"alert",
                                  @"badge": @2,
                                  @"sound": @"cat",
                                  @"category": @"category",
                                  @"content-available": @1
                                  }
                          };

    self.notificationWithBody = @{
                                  @"aps": @{
                                          @"alert": @{
                                                  @"title": @"alertTitle",
                                                  @"body": @"alertBody",
                                                  @"loc-key": @"localizationKey",
                                                  @"action-loc-key": @"actionLocalizationKey",
                                                  @"loc-args":@"localizationArguments",
                                                  @"title-loc-key": @"titleLocalizationKey",
                                                  @"title-loc-args": @"titleLocalizationArguments",
                                                  @"launch-image":@"launchImage"
                                                  },
                                          @"badge": @2,
                                          @"sound": @"cat",
                                          @"category": @"category",
                                          @"content-available": @1
                                          },
                                  };
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// Tests notification content creation when the input notification dictionary does not include an alert body
-(void)testNotificationContentFromNotificationDictionary {
    UANotificationContent *notification = [UANotificationContent notificationWithNotificationInfo:self.notification];

    // Alert Body
    XCTAssertTrue([notification.alertBody isEqualToString:self.notification[@"aps"][@"alert"]]);

    // Badge
    XCTAssertTrue([notification.badgeNumber isEqualToNumber:self.notificationWithBody[@"aps"][@"badge"]]);

    // Sound
    XCTAssertTrue([notification.sound isEqualToString:self.notificationWithBody[@"aps"][@"sound"]]);

    // Content Available
    XCTAssertTrue([notification.contentAvailable isEqualToNumber:self.notificationWithBody[@"aps"][@"content-available"]]);

    // Category
    XCTAssertTrue([notification.category isEqualToString:self.notificationWithBody[@"aps"][@"category"]]);

    // Raw Notification
    XCTAssertTrue([notification.notificationInfo isEqualToDictionary:self.notification]);
}

// Tests notification content creation when the input notification dictionary includes a alert body
-(void)testNotificationContentFromNotificationDictionaryWithAlertBody {
    UANotificationContent *notification = [UANotificationContent notificationWithNotificationInfo:self.notificationWithBody];

    // Alert Title
    XCTAssertTrue([notification.alertTitle isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"title"]]);

    // Alert Body
    XCTAssertTrue([notification.alertBody isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"body"]]);

    // Badge
    XCTAssertTrue(notification.badgeNumber == self.notificationWithBody[@"aps"][@"badge"]);

    // Sound
    XCTAssertTrue([notification.sound isEqualToString:self.notificationWithBody[@"aps"][@"sound"]]);

    // Content Available
    XCTAssertTrue([notification.contentAvailable isEqualToNumber:self.notificationWithBody[@"aps"][@"content-available"]]);

    // Category
    XCTAssertTrue([notification.category isEqualToString:self.notificationWithBody[@"aps"][@"category"]]);

    // Localization Keys
    XCTAssertTrue([notification.localizationKeys[@"loc-key"] isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"loc-key"]]);
    XCTAssertTrue([notification.localizationKeys[@"action-loc-key"] isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"action-loc-key"]]);
    XCTAssertTrue([notification.localizationKeys[@"title-loc-key"] isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"title-loc-key"]]);
    XCTAssertTrue([notification.localizationKeys[@"title-loc-args"] isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"title-loc-args"]]);

    // Launch Image
    XCTAssertTrue([notification.launchImage isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"launch-image"]]);

    // Raw Notification
    XCTAssertTrue([notification.notificationInfo isEqualToDictionary:self.notificationWithBody]);
}

@end
