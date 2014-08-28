/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAInboxDBManager+Internal.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"

@interface UAInboxDBManagerTests : XCTestCase
@property (nonatomic, strong) UAInboxDBManager *dbManager;
@end

@implementation UAInboxDBManagerTests

- (void)setUp {
    self.dbManager = [UAInboxDBManager shared];
    [self.dbManager deleteMessages:[self.dbManager getMessages]];
    [super setUp];
}

- (void)tearDown {
    [self.dbManager deleteMessages:[self.dbManager getMessages]];
    [super tearDown];
}

- (void)testAddMessageFromDictionary {
    NSDictionary *messageDictionary = [self createMessageDictionaryWithMessageID:@"someId"];
    [self.dbManager addMessageFromDictionary:messageDictionary];

    NSArray *messages = [self.dbManager getMessages];

    XCTAssertEqual((NSUInteger)1, messages.count, @"Unable to add message from dictionary to inbox database store");
    [self verifyMessage:[messages lastObject] withDictionary:messageDictionary];
}

- (void)testAddMessageFromDictioanryEmptyDictionary {
    [self.dbManager addMessageFromDictionary:@{}];

    NSArray *messages = [self.dbManager getMessages];

    XCTAssertEqual((NSUInteger)1, messages.count, @"Unable to add message from dictionary to inbox database store");
    [self verifyMessage:[messages lastObject] withDictionary:@{}];
}

- (void)testAddMessageFromDictionaryNilDictionary {
    [self.dbManager addMessageFromDictionary:nil];

    NSArray *messages = [self.dbManager getMessages];

    XCTAssertEqual((NSUInteger)1, messages.count, @"Unable to add message from dictionary to inbox database store");

    [self verifyMessage:[messages lastObject] withDictionary:@{}];
}

- (void)testUpdateMessageFromDictionaryEmptyMessages {
    NSDictionary *messageDictionary = [self createMessageDictionaryWithMessageID:@"someId"];
    XCTAssertFalse([self.dbManager updateMessageWithDictionary:messageDictionary], @"Update message returned YES when it should have no message to update.");
}

- (void)testUpdateMessageFromDictionaryNewMessages {
    [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"someId"]];

    NSDictionary *messageDictionary = [self createMessageDictionaryWithMessageID:@"someOtherId"];
    XCTAssertFalse([self.dbManager updateMessageWithDictionary:messageDictionary], @"Update message returned YES when it should not have a matching message to update.");
}

- (void)testUpdateMessage {
    // Add a message
    NSDictionary *messageDictionary = [[self createMessageDictionaryWithMessageID:@"someId"] mutableCopy];
    [self.dbManager addMessageFromDictionary:messageDictionary];

    // Modify the dictionary
    [messageDictionary setValue:@"I am title" forKey:@"title"];

    // Update message with modified dictionary
    XCTAssertTrue([self.dbManager updateMessageWithDictionary:messageDictionary], @"Update message failed to update a message.");

    // Verify the message is updated
    NSArray *messages = [self.dbManager getMessages];
    XCTAssertEqual((NSUInteger)1, messages.count, @"Updating a message changed the amount of messages");
    [self verifyMessage:[messages lastObject] withDictionary:messageDictionary];
}

- (void)testDeleteMessagesAll {
    NSMutableArray *messagesToDelete = [NSMutableArray array];
    [messagesToDelete addObject:[self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"anotherId"]]];
    [messagesToDelete addObject:[self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"yetAnotherId"]]];

    XCTAssertEqual((NSUInteger)2, [self.dbManager getMessages].count, @"2 messages should of been added");

    [self.dbManager deleteMessages:messagesToDelete];
    XCTAssertEqual((NSUInteger)0, [self.dbManager getMessages].count, @"All of the messages should be deleted");

    // Try to delete them again make sure it does not throw
    XCTAssertNoThrow([self.dbManager deleteMessages:messagesToDelete], @"Deleted messages twice causes an exception to be thrown");
    XCTAssertEqual((NSUInteger)0, [self.dbManager getMessages].count, @"All of the messages should be deleted");
}

- (void)testDeleteMessages {
    NSMutableArray *messagesToDelete = [NSMutableArray array];
    [messagesToDelete addObject:[self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"anotherId"]]];

    NSDictionary *messageDictionary = [self createMessageDictionaryWithMessageID:@"anotherMessageId"];
    [self.dbManager addMessageFromDictionary:messageDictionary];

    XCTAssertEqual((NSUInteger)2, [self.dbManager getMessages].count, @"2 messages should of been added");

    [self.dbManager deleteMessages:messagesToDelete];
    XCTAssertEqual((NSUInteger)1, [self.dbManager getMessages].count, @"Only one of the messages should of been deleted");
    [self verifyMessage:[[self.dbManager getMessages] lastObject] withDictionary:messageDictionary];
}

- (void)testDeleteMessagesEmptyArray {
    XCTAssertNoThrow([self.dbManager deleteMessages:[NSArray array]], @"Deleting messagse with an empty array is causing an exception to be thrown");
}

- (void)testDeleteMessagesNilArray {
    XCTAssertNoThrow([self.dbManager deleteMessages:nil], @"Deleting messagse with a nil array is causing an exception to be thrown");
}

- (void)testDeleteMessagesInvalidArray {
    NSArray *invalidArray = @[@1, @"what", [NSArray array]];
    XCTAssertNoThrow([self.dbManager deleteMessages:invalidArray], @"Deleting invalid messages should not result in an exception");
}

- (void)testDeleteMessagesWithIDs {
    // Add 2 messages
    [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"anotherId"]];
    [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"anotherMessageId"]];

    XCTAssertEqual((NSUInteger)2, [self.dbManager getMessages].count, @"2 messages should of been added");

    [self.dbManager deleteMessagesWithIDs:[NSSet setWithArray:@[@"anotherId"]]];
    XCTAssertEqual((NSUInteger)1, [self.dbManager getMessages].count, @"Only one of the messages should of been deleted");
    [self verifyMessage:[[self.dbManager getMessages] lastObject] withDictionary:[self createMessageDictionaryWithMessageID:@"anotherMessageId"]];
}

- (void)testMessageIDs {
    // Add 2 messages
    [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"anotherId"]];
    [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"anotherMessageId"]];

    XCTAssertTrue([[self.dbManager messageIDs] containsObject:@"anotherId"], @"messageIDs not returning all the added messages");
    XCTAssertTrue([[self.dbManager messageIDs] containsObject:@"anotherMessageId"], @"messageIDs not returning all the added messages");
    XCTAssertEqual((NSUInteger)2, [self.dbManager messageIDs].count, @"messageIDs should only contain 2 IDs");
}

- (void)testDeleteExpiredMessages {
    NSDate *currentDate = [NSDate date];

    // Mock the date to always return currentDate
    id mockDate = [OCMockObject mockForClass:[NSDate class]];
    [[[mockDate stub] andReturn:currentDate] date];
    
    XCTAssertNoThrow([self.dbManager deleteExpiredMessages], @"Deleting expired messages on empty database should not throw");

    NSArray *unExpiredMessageDicts = @[[self createMessageDictionaryWithMessageID:@"noExpiration"],
                                       [self createMessageDictionaryWithMessageID:@"notExpired" expirationDate:[currentDate dateByAddingTimeInterval:1]]];

    // Add the unexpired messages
    for (NSDictionary *dict in unExpiredMessageDicts) {
        [self.dbManager addMessageFromDictionary:dict];
    }

    // Add 2 message that are expired
    [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"expiredOne" expirationDate:currentDate]];
    [self.dbManager addMessageFromDictionary:[self createMessageDictionaryWithMessageID:@"expiredTwo" expirationDate:[currentDate dateByAddingTimeInterval:-1]]];

    [self.dbManager deleteExpiredMessages];

    // Verify the unExpiredMessages still exist
    for (NSDictionary *dict in unExpiredMessageDicts) {
        NSString *messageId = [dict valueForKey:@"message_id"];
        XCTAssertTrue([[self.dbManager messageIDs] containsObject:messageId], @"Expected unexpired message with id %@ to not be deleted", messageId);
    }

    XCTAssertEqual((NSUInteger)2, [self.dbManager messageIDs].count, @"messageIDs should only contain 2 IDs");


    [mockDate stopMocking];
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

- (NSDictionary *)createMessageDictionaryWithMessageID:(NSString *)messageID expirationDate:(NSDate *)date {
    NSMutableDictionary *dictionary = [[self createMessageDictionaryWithMessageID:messageID] mutableCopy];
    NSString *dateString = [[UAUtils ISODateFormatterUTC] stringFromDate:date];

    [dictionary setValue:dateString forKey:@"message_expiry"];
    return dictionary;
}

- (void) verifyMessage:(UAInboxMessage *)message withDictionary:(NSDictionary *)dictionary {
    XCTAssertEqualObjects([dictionary valueForKey:@"message_id"], message.messageID, @"Message's id does not match the expected message id");
    XCTAssertEqualObjects([dictionary valueForKey:@"title"], message.title, @"Message's title does not match the expected message title");
    XCTAssertEqualObjects([dictionary valueForKey:@"content_type"], message.contentType, @"Message's content type does not match the expected message content type");
    XCTAssertEqualObjects([dictionary valueForKey:@"message_url"], [message.messageURL absoluteString], @"Message's url does not match the expected message url");
    XCTAssertEqualObjects([dictionary valueForKey:@"message_body_url"], [message.messageBodyURL absoluteString], @"Message's body url does not match the expected message body url");
    XCTAssertEqualObjects([dictionary valueForKey:@"extra"], message.extra, @"Message's extras does not match the expected message extras");
    XCTAssertEqual([[dictionary valueForKey:@"unread"] boolValue], message.unread, @"Message's unread does not match the expected message unread");
    XCTAssertEqualObjects([[UAUtils ISODateFormatterUTC] dateFromString:[dictionary objectForKey: @"message_sent"]], message.messageSent, @"Message's messageSent does not match the expected messageSent");
}

@end
