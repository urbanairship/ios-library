/* Copyright Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxMessageList+Internal.h"

@interface UAInboxMessageTest : UABaseTest
@end

@implementation UAInboxMessageTest

- (UAInboxMessage *)createMessageWithID:(NSString *)messageID expiration:(NSDate *)expiration {
    return [UAInboxMessage messageWithBuilderBlock:^(UAInboxMessageBuilder *builder) {
        builder.messageID = messageID;
        builder.title = @"someTitle";
        builder.contentType =  @"someContentType";
        builder.extra = @{@"someKey":@"someValue"};
        builder.messageBodyURL = [NSURL URLWithString:@"http://someMessageUrl"];
        builder.unread = YES;
        builder.messageSent = [NSDate date];
        builder.messageExpiration = expiration;
    }];
}

- (void)setUp {
    [super setUp];
}

/**
 * Test isExpired
 */
- (void)testIsExpired {

    NSDate *currentDate = [NSDate date];

    // Mock the date to always return currentDate
    id mockDate = [self mockForClass:[NSDate class]];
    [[[mockDate stub] andReturn:currentDate] date];

    UAInboxMessage *message = [self createMessageWithID:@"1234" expiration:nil];
    XCTAssertFalse([message isExpired], @"A message cannnot expire if the expiration date is nil");

    message = [self createMessageWithID:@"1234" expiration:[currentDate dateByAddingTimeInterval:1]];
    XCTAssertFalse([message isExpired], @"messageExpiration is after the current date");

    message = [self createMessageWithID:@"1234" expiration:currentDate];
    XCTAssertTrue([message isExpired], @"messageExpiration is exactly the current date");

    message = [self createMessageWithID:@"1234" expiration:[currentDate dateByAddingTimeInterval:-1]];
    XCTAssertTrue([message isExpired], @"messageExpiration is before the current date");

    [mockDate stopMocking];
}


@end
