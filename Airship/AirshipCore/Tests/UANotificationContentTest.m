/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UANotificationContent.h"
#import <UserNotifications/UserNotifications.h>

@interface UANotificationContentTest : UABaseTest

@property (nonatomic, strong) id mockedUNNotification;
@property (nonatomic, copy) NSDictionary *notification;
@property (nonatomic, copy) NSDictionary *notificationWithBody;
@property (nonatomic, copy) NSString *testKey;
@property (nonatomic, copy) NSString *testValue;

@end

@implementation UANotificationContentTest

- (void)setUp {
    [super setUp];

    self.mockedUNNotification = [self mockForClass:[UNNotification class]];

    self.testKey = nil;
    self.testValue = nil;
    self.notification = @{
                          @"aps": @{
                                  @"alert": @"alert",
                                  @"badge": @2,
                                  @"sound": @"cat",
                                  @"category": @"category",
                                  @"content-available": @1,
                                  @"thread-id" : @"test-thread",
                                  @"target-content-id" : @"test-target",
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
                                                  @"launch-image":@"launchImage",
                                                  @"summary-arg" : @"summary-arg-1",
                                                  @"summary-arg-count" : @1
                                                  },
                                          @"badge": @2,
                                          @"sound": @"cat",
                                          @"category": @"category",
                                          @"thread-id" : @"test-thread",
                                          @"target-content-id" : @"test-target",
                                          @"content-available": @1
                                          },
                                  };
}

- (void)tearDown {
    [self.mockedUNNotification stopMocking];
    [super tearDown];
}

// Tests UNNotification is properly initialized when a UANotificationContent instance is created from a UNNotification
-(void)testNotificationContentFromUNNotification {

    UANotificationContent *notificationContent = [UANotificationContent notificationWithUNNotification:self.mockedUNNotification];

    XCTAssertEqualObjects(notificationContent.notification, self.mockedUNNotification);
}

// Tests notification content creation when the input notification dictionary does not include an alert body
-(void)testNotificationContentFromNotificationDictionary {
    UANotificationContent *notification = [UANotificationContent notificationWithNotificationInfo:self.notification];

    // Alert Body
    XCTAssertTrue([notification.alertBody isEqualToString:self.notification[@"aps"][@"alert"]]);

    // Badge
    XCTAssertTrue([notification.badge isEqualToNumber:self.notificationWithBody[@"aps"][@"badge"]]);

    // Sound
    XCTAssertTrue([notification.sound isEqualToString:self.notificationWithBody[@"aps"][@"sound"]]);

    // Category
    XCTAssertTrue([notification.categoryIdentifier isEqualToString:self.notificationWithBody[@"aps"][@"category"]]);

    // Thread
    XCTAssertTrue([notification.threadIdentifier isEqualToString:self.notificationWithBody[@"aps"][@"thread-id"]]);

    //Target identifier
    XCTAssertTrue([notification.targetContentIdentifier isEqualToString:self.notificationWithBody[@"aps"][@"target-content-id"]]);
    
    // Raw Notification
    XCTAssertTrue([notification.notificationInfo isEqualToDictionary:self.notification]);
}

// Tests notification content creation when the input notification dictionary includes an alert body

-(void)testNotificationContentFromNotificationDictionaryWithAlertBody {
    UANotificationContent *notification = [UANotificationContent notificationWithNotificationInfo:self.notificationWithBody];

    // Alert Title
    XCTAssertTrue([notification.alertTitle isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"title"]]);

    // Alert Body
    XCTAssertTrue([notification.alertBody isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"body"]]);

    // Badge
    XCTAssertTrue(notification.badge == self.notificationWithBody[@"aps"][@"badge"]);

    // Sound
    XCTAssertTrue([notification.sound isEqualToString:self.notificationWithBody[@"aps"][@"sound"]]);

    // Category
    XCTAssertTrue([notification.categoryIdentifier isEqualToString:self.notificationWithBody[@"aps"][@"category"]]);

    // Thread
    XCTAssertTrue([notification.threadIdentifier isEqualToString:self.notificationWithBody[@"aps"][@"thread-id"]]);

    //Target identifier
    XCTAssertTrue([notification.targetContentIdentifier isEqualToString:self.notificationWithBody[@"aps"][@"target-content-id"]]);
    
    // Summary Arg
    XCTAssertTrue([notification.summaryArgument isEqualToString:self.notificationWithBody[@"aps"][@"alert"][@"summary-arg"]]);

    // Summary Arg Count
    XCTAssertTrue(notification.summaryArgumentCount == self.notificationWithBody[@"aps"][@"alert"][@"summary-arg-count"]);

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
