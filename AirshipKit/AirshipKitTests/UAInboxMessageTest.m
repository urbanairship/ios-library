/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import <OCMock/OCMock.h>
#import "UAInboxMessage.h"
#import "UAInboxMessage+Internal.h"
#import "UAInbox.h"
#import "UAInboxDBManager+Internal.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAConfig.h"

@interface UAInboxMessageTest : UABaseTest
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
    id mockDate = [self mockForClass:[NSDate class]];
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
