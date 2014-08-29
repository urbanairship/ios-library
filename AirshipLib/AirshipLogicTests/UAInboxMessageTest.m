
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInboxMessage.h"
#import "UAInboxMessage+Internal.h"
#import "UAInbox.h"
#import "UAInboxDBManager.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxMessageListDelegate.h"
#import "UAInboxAPIClient.h"

@interface UAInboxMessageTest : XCTestCase


@property (nonatomic, strong) UAInboxDBManager *dbManager;
@property (nonatomic, strong) UAInboxMessage *message;

//a mock (old-school) message list observer that will receive deprecated callbacks
@property (nonatomic, strong) id mockMessageListObserver;
//a mock delegate we'll pass into the appropriate methods for callbacks
@property (nonatomic, strong) id mockMessageListDelegate;

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
    self.dbManager = [UAInboxDBManager shared];
    [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"12345"]];
    self.message = [[self.dbManager fetchMessagesWithPredicate:nil] objectAtIndex:0];

    self.message.data.unread = YES;
    //this is normally set when a message is associated with the message list, needed for
    //sending (deprecated) UAInboxMessageListObserver callbacks
    self.message.inbox = self.messageList = [[UAInboxMessageList alloc] init];

    self.mockMessageListDelegate = [OCMockObject mockForProtocol:@protocol(UAInboxMessageListDelegate)];

    //order is important with these events, so we should be explicit about it
    [self.mockMessageListObserver setExpectationOrderMatters:YES];
    [self.mockMessageListDelegate setExpectationOrderMatters:YES];
}

- (void)tearDown {
    // Put teardown code here; it will be run once, after the last test case.
    //undo observer sign-ups
    [self.mockMessageListObserver stopMocking];
    [self.mockMessageListDelegate stopMocking];
    [self.dbManager deleteMessages:[self.dbManager fetchMessagesWithPredicate:nil]];
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
