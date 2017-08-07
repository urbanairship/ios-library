/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInboxStore+Internal.h"
#import "UAConfig.h"

@interface UAInboxStoreTest : UABaseTest
@property UAInboxStore *inboxStore;
@end

@implementation UAInboxStoreTest

- (void)setUp {
    [super setUp];
    self.inboxStore = [[UAInboxStore alloc] initWithConfig:[UAConfig config]];
}

- (void)testDefaultValues {

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"test finished"];

    [self.inboxStore syncMessagesWithResponse:@[[self createMessageDictionaryWithMessageID:@"messageID"]]
                                                completionHandler:^(BOOL success) {
                                                    XCTAssertTrue(success);
                                                }];

    [self.inboxStore fetchMessagesWithPredicate:nil
                              completionHandler:^(NSArray<UAInboxMessageData *> *messages) {
        XCTAssertEqual(1, messages.count);
        XCTAssertTrue(messages[0].unreadClient);
        XCTAssertFalse(messages[0].deletedClient);

        [testExpectation fulfill];
    }];

     [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testSyncMessages {


    NSArray *messages = @[ [self createMessageDictionaryWithMessageID:@"message-0"],
                           [self createMessageDictionaryWithMessageID:@"message-1"],
                           [self createMessageDictionaryWithMessageID:@"message-2"]];


    [self.inboxStore syncMessagesWithResponse:messages
                            completionHandler:^(BOOL success) {
                                XCTAssertTrue(success);
                            }];


    // Verify we have 3 messages
    XCTestExpectation *firstFetch = [self expectationWithDescription:@"fetched messages"];
    [self.inboxStore fetchMessagesWithPredicate:nil
                              completionHandler:^(NSArray<UAInboxMessageData *> *messages) {
                                  XCTAssertEqual(3, messages.count);
                                  [firstFetch fulfill];
                              }];


    // Modify one of the messages
    NSMutableDictionary *message = [messages[1] mutableCopy];
    message[@"title"] = @"differentTitle";


    // Sync only the modified message
    [self.inboxStore syncMessagesWithResponse:@[message]
                            completionHandler:^(BOOL success) {
                                XCTAssertTrue(success);
                            }];

    // Verify we only have the modified message with the updated title
    XCTestExpectation *secondFetch = [self expectationWithDescription:@"fetched messages"];
    [self.inboxStore fetchMessagesWithPredicate:nil
                              completionHandler:^(NSArray<UAInboxMessageData *> *messages) {
                                  XCTAssertEqual(1, messages.count);
                                  XCTAssertEqualObjects(@"differentTitle", messages[0].title);
                                  [secondFetch fulfill];
                              }];

    [self waitForExpectationsWithTimeout:5 handler:nil];


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
