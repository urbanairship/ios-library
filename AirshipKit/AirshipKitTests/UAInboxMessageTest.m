/* Copyright Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxMessageList+Internal.h"
#import "UATestDate.h"

@interface UAInboxMessageTest : UABaseTest
@property (nonatomic, strong) UATestDate *testDate;
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
        builder.date = self.testDate;
    }];
}

- (void)setUp {
    [super setUp];

    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
}

/**
 * Test isExpired
 */
- (void)testIsExpired {
    NSDate *currentDate = [self.testDate now];

    UAInboxMessage *message = [self createMessageWithID:@"1234" expiration:nil];
    XCTAssertFalse([message isExpired], @"A message cannnot expire if the expiration date is nil");

    message = [self createMessageWithID:@"1234" expiration:[currentDate dateByAddingTimeInterval:1]];
    XCTAssertFalse([message isExpired], @"messageExpiration is after the current date");

    message = [self createMessageWithID:@"1234" expiration:currentDate];
    XCTAssertTrue([message isExpired], @"messageExpiration is exactly the current date");

    message = [self createMessageWithID:@"1234" expiration:[currentDate dateByAddingTimeInterval:-1]];
    XCTAssertTrue([message isExpired], @"messageExpiration is before the current date");
}


@end
