/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInboxStore+Internal.h"

@interface UAInboxStoreTest : UABaseTest
@property UAInboxStore *inboxStore;
@end

@implementation UAInboxStoreTest

- (void)setUp {
    [super setUp];
    self.inboxStore = [UAInboxStore storeWithName:[NSUUID UUID].UUIDString inMemory:YES];
}

- (void)tearDown {
    [self.inboxStore shutDown];
    [super tearDown];
}

- (void)testSyncMessages {
    NSArray *messagesDict = @[[self createMessageDictionaryWithMessageID:@"message-0"],
                              [self createMessageDictionaryWithMessageID:@"message-1"],
                              [self createMessageDictionaryWithMessageID:@"message-2"]];


    BOOL success = [self.inboxStore syncMessagesWithResponse:messagesDict];
    XCTAssertTrue(success);

    NSArray<UAInboxMessage *> *messages = [self.inboxStore fetchMessagesWithPredicate:nil];
    XCTAssertEqual(3, messages.count);


    // Modify one of the messages
    NSMutableDictionary *message = [messagesDict[1] mutableCopy];
    message[@"title"] = @"differentTitle";

    success = [self.inboxStore syncMessagesWithResponse:@[message]];
    XCTAssertTrue(success);

    // Verify we only have the modified message with the updated title
    messages = [self.inboxStore fetchMessagesWithPredicate:nil];
    XCTAssertEqual(1, messages.count);
    XCTAssertEqualObjects(@"differentTitle", messages[0].title);
}

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

@end
