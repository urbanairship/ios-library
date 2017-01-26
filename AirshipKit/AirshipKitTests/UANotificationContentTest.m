/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UANotificationContent.h"
#import <UserNotifications/UserNotifications.h>

@interface UANotificationContentTest : XCTestCase

@property (nonatomic, strong) id mockedUNNotification;
@property (nonatomic, strong) NSDictionary *notification;
@property (nonatomic, strong) NSDictionary *notificationWithBody;
@property (nonatomic, strong) NSString *testKey;
@property (nonatomic, strong) NSString *testValue;

@end

@implementation UANotificationContentTest

- (void)setUp {
    [super setUp];

    self.mockedUNNotification = [OCMockObject niceMockForClass:[UNNotification class]];

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
