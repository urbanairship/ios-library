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
#import "UAInboxMessage.h"
#import "UAInboxMessage+Internal.h"
#import "UAInbox.h"
#import "UAInboxDBManager+Internal.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAConfig.h"

@interface UAInboxMessageTest : XCTestCase
@property (nonatomic, strong) UAInboxDBManager *dbManager;
@property (nonatomic, strong) UAInboxMessage *message;
@property (nonatomic, strong) UAInboxMessageList *messageList;
@end

@implementation UAInboxMessageTest

- (NSDictionary *)createMessageDictionaryWithMessageID:(NSString *)messageID {
    return @{@"message_id": messageID,
             @"title": @"someTitle",
             @"content_type": @"someContentType",
             @"extra": @{@"someKey":@"someValue"},
             @"message_body_url": @"http://someMessageBodyUrl",
             @"message_url": @"http://someMessageUrl",
             @"unread": @"0",
             @"message_sent": @"2013-08-13 00:16:22" };

}

- (void)setUp {
    [super setUp];

    self.dbManager = [[UAInboxDBManager alloc] initWithConfig:[UAConfig config]];

    self.message = [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"12345"] context:self.dbManager.mainContext];
    self.message.data.unread = YES;
    //this is normally set when a message is associated with the message list, needed for
    //sending (deprecated) UAInboxMessageListObserver callbacks
    self.message.inbox = self.messageList = [[UAInboxMessageList alloc] init];
}

- (void)tearDown {
    // Put teardown code here; it will be run once, after the last test case.
    [self.dbManager fetchMessagesWithPredicate:[NSPredicate predicateWithValue:true] context:self.dbManager.mainContext completionHandler:^(NSArray *messages){
        [self.dbManager deleteMessages:messages context:self.dbManager.mainContext];
    }];
    [super tearDown];
}

/**
 * Test isExpired
 */
- (void)testIsExpired {

    NSDate *currentDate = [NSDate date];

    // Mock the date to always return currentDate
    id mockDate = [OCMockObject mockForClass:[NSDate class]];
    [[[mockDate stub] andReturn:currentDate] date];

    self.message.data.messageExpiration = nil;
    XCTAssertFalse([self.message isExpired], @"A message cannnot expire if the expiration date is nil");

    self.message.data.messageExpiration = [currentDate dateByAddingTimeInterval:1];
    XCTAssertFalse([self.message isExpired], @"messageExpiration is after the current date");

    self.message.data.messageExpiration = currentDate;
    XCTAssertTrue([self.message isExpired], @"messageExpiration is exactly the current date");

    self.message.data.messageExpiration = [currentDate dateByAddingTimeInterval:-1];
    XCTAssertTrue([self.message isExpired], @"messageExpiration is before the current date");

    [mockDate stopMocking];
}


@end
