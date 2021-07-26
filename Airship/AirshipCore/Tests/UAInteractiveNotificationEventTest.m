/* Copyright Airship and Contributors */

#import "UABaseTest.h"
@import UserNotifications;

@import AirshipCore;

@interface UAInteractiveNotificationEventTest : UABaseTest
@property (nonatomic, copy) NSDictionary *notification;
@property (nonatomic, strong) UNNotificationAction *action;
@end

@implementation UAInteractiveNotificationEventTest

- (void)setUp {
    [super setUp];

    self.notification = @{ @"aps": @{ @"alert": @"sample alert!",
                                      @"badge": @2,
                                      @"sound": @"cat",
                                      @"category": @"notificationCategory"
    },
                           @"_": @"send ID"
    };

    self.action = [UNNotificationAction actionWithIdentifier:@"action_identifier"
                                                       title:@"action_title"
                                                     options:(UNNotificationActionOptions)UNNotificationActionOptionForeground];
}

/**
 * Test the event type is interactive_notification_action.
 */
- (void)testEventType {
    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc] initWithAction:self.action
                                                                                          category:@"category_id"
                                                                                      notification:self.notification
                                                                                      responseText:@"hello"];
    XCTAssertEqualObjects(event.eventType, @"interactive_notification_action", @"Event has wrong type.");
}

/**
 * Test the event payload when its created with a foreground action.
 */
- (void)testEventDataForegroundAction {

    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc ] initWithAction:self.action
                                                                                           category:@"category_id"
                                                                                       notification:self.notification                               responseText:nil];


    NSDictionary *expectedData = @{@"foreground": @"true",
                                   @"button_id": @"action_identifier",
                                   @"button_description": @"action_title",
                                   @"button_group": @"category_id",
                                   @"send_id": @"send ID"};

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
}


/**
 * Test the event payload when its created with a background action.
 */
- (void)testEventDataBackgroundAction {
    self.action = [UNNotificationAction actionWithIdentifier:@"action_identifier"
                                                       title:@"action_title"
                                                     options:0];

    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc] initWithAction:self.action
                                                                                          category:@"category_id"
                                                                                      notification:self.notification
                                                                                      responseText:nil];

    NSDictionary *expectedData = @{@"foreground": @"false",
                                   @"button_id": @"action_identifier",
                                   @"button_description": @"action_title",
                                   @"button_group": @"category_id",
                                   @"send_id": @"send ID"};

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
}

/**
 * Test the event is high priority
 */
- (void)testHighPriority {
    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc] initWithAction:self.action
                                                                                          category:@"category_id"
                                                                                      notification:self.notification
                                                                                      responseText:@"hello"];


    XCTAssertEqual(UAEventPriorityHigh, event.priority);
}

/**
 * Test the event payload when its created with a responseInfo.
 */
- (void)testEventResponseInfo {
    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc] initWithAction:self.action
                                                                                          category:@"category_id"
                                                                                      notification:self.notification
                                                                                      responseText:@"hello"];

    NSDictionary *expectedData = @{@"foreground": @"true",
                                   @"button_id": @"action_identifier",
                                   @"button_description": @"action_title",
                                   @"button_group": @"category_id",
                                   @"send_id": @"send ID",
                                   @"user_input": @"hello"};

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
}

/**
 * Test when the user_input has greater than max acceptable length gets truncated.
 */
- (void)testEventOverMaxUserInput {

    NSString *overMaxUserInput = [@"" stringByPaddingToLength:256 withString:@"User_INPUT" startingAtIndex:0];

    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc] initWithAction:self.action
                                                                                          category:@"category_id"
                                                                                      notification:self.notification
                                                                                      responseText:overMaxUserInput];

    NSString *maxUserInput = [@"" stringByPaddingToLength:255 withString:@"User_INPUT" startingAtIndex:0];

    NSDictionary *expectedData = @{@"foreground": @"true",
                                   @"button_id": @"action_identifier",
                                   @"button_description": @"action_title",
                                   @"button_group": @"category_id",
                                   @"send_id": @"send ID",
                                   @"user_input": maxUserInput};

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
}

/**
 * Test when the user_input has max acceptable length.
 */
- (void)testEventMaxUserInput {

    NSString *maxUserInput = [@"" stringByPaddingToLength:255 withString:@"User_INPUT" startingAtIndex:0];

    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc] initWithAction:self.action
                                                                                          category:@"category_id"
                                                                                      notification:self.notification
                                                                                      responseText:maxUserInput];

    NSDictionary *expectedData = @{@"foreground": @"true",
                                   @"button_id": @"action_identifier",
                                   @"button_description": @"action_title",
                                   @"button_group": @"category_id",
                                   @"send_id": @"send ID",
                                   @"user_input": maxUserInput};

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
}

/**
 * Test when the user_input is an empty string.
 */
- (void)testEventEmptyUserInput {
    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc] initWithAction:self.action
                                                                                          category:@"category_id"
                                                                                      notification:self.notification
                                                                                      responseText:@""];

    NSDictionary *expectedData = @{@"foreground": @"true",
                                   @"button_id": @"action_identifier",
                                   @"button_description": @"action_title",
                                   @"button_group": @"category_id",
                                   @"send_id": @"send ID",
                                   @"user_input": @""};

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
}

@end



