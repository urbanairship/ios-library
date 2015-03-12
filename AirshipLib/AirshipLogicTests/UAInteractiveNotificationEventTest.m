/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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
#import "UAInteractiveNotificationEvent.h"

@interface UAInteractiveNotificationEventTest : XCTestCase
@property (nonatomic, strong) NSDictionary *notification;
@property (nonatomic, strong) UIMutableUserNotificationAction *action;
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

    self.action = [[UIMutableUserNotificationAction alloc] init];
    self.action.identifier = @"action_identifier";
    self.action.title = @"action_title";

}

/**
 * Test the estimated size of the event. Should always return 350 regardless
 * of the actual event data.
 */
- (void)testEstimatedSize {
    // Empty
    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc] init];
    XCTAssertEqual(event.estimatedSize, 350, @"Event should have a set estimated size." );

    // With data
    event = [UAInteractiveNotificationEvent eventWithNotificationAction:self.action
                                                             categoryID:@"category_id"
                                                           notification:self.notification];

    XCTAssertEqual(event.estimatedSize, 350, @"Event should have a set estimated size." );
}

/**
 * Test the event type is interactive_notification_action.
 */
- (void)testEventType {
    UAInteractiveNotificationEvent *event = [[UAInteractiveNotificationEvent alloc] init];
    XCTAssertEqual(event.eventType, @"interactive_notification_action", @"Event has wrong type.");
}

/**
 * Test the event payload when its created with empty objects.
 */
- (void)testEventDataEmpty {
    UAInteractiveNotificationEvent *event = [UAInteractiveNotificationEvent eventWithNotificationAction:nil
                                                                                             categoryID:nil
                                                                                           notification:nil];


    NSDictionary *expectedData = @{@"foreground": @"true"};

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
}

/**
 * Test the event payload when its created with a foreground action.
 */
- (void)testEventDataForegroundAction {

    UAInteractiveNotificationEvent *event = [UAInteractiveNotificationEvent eventWithNotificationAction:self.action
                                                                                             categoryID:@"category_id"
                                                                                           notification:self.notification];

    NSDictionary *expectedData = @{@"foreground": @"true",
                     @"button_id": @"action_identifier",
                     @"button_description": @"action_title",
                     @"button_group": @"category_id",
                     @"send_id": @"send ID"};

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
}


/**
 * Test the event payload when its created with a background action.
 */
- (void)testEventDataBackgroundAction {
    self.action.activationMode = UIUserNotificationActivationModeBackground;
    UAInteractiveNotificationEvent *event = [UAInteractiveNotificationEvent eventWithNotificationAction:self.action
                                                                                             categoryID:@"category_id"
                                                                                           notification:self.notification];

    NSDictionary *expectedData = @{@"foreground": @"false",
                     @"button_id": @"action_identifier",
                     @"button_description": @"action_title",
                     @"button_group": @"category_id",
                     @"send_id": @"send ID"};

    XCTAssertEqualObjects(event.data, expectedData, @"Event data is unexpected.");
    XCTAssertNotNil(event.eventID, @"Event should have an ID");
}

@end
