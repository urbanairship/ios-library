/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UADate+Internal.h"
#import "UAUtils+Internal.h"
#import "UAAttributePendingMutations+Internal.h"
#import "UAAttributeMutations+Internal.h"
#import "UATestDate.h"

@interface UAAttributePendingMutationsTest : UABaseTest
@property (nonatomic, strong) UATestDate *testDate;
@end

@implementation UAAttributePendingMutationsTest

- (void)setUp {
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
}

/**
 Test pending mutations wraps payload in attributes-keyed dictionary entry and adds timestamps
*/
-(void)testPendingMutationsPayload {
    NSDateFormatter *isoDateFormatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
    NSString *timestamp = [isoDateFormatter stringFromDate:self.testDate.now];

    NSDictionary *expectedPayload = @{
        @"attributes" : @[
            @{
                @"action" : @"set",
                @"key" : @"jam",
                @"timestamp" : timestamp,
                @"value" : @"space"
            },
            @{
                @"action" : @"set",
                @"key" : @"game",
                @"timestamp" : timestamp,
                @"value" : @"goose"
            },
            @{
                @"action" : @"remove",
                @"timestamp" : timestamp,
                @"key" : @"game",
            }
        ]
    };

    UAAttributeMutations *mutations = [UAAttributeMutations mutations];

    [mutations setString:@"space" forAttribute:@"jam"];
    [mutations setString:@"goose" forAttribute:@"game"];
    [mutations removeAttribute:@"game"];

    UAAttributePendingMutations *pendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:mutations         date:self.testDate];

    XCTAssertEqualObjects(pendingMutations.payload, expectedPayload);
}

/**
 Test adding twice then removing mutation results in a remove
*/
-(void)testAddAddRemove {
    NSDateFormatter *isoDateFormatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
    NSString *timestamp = [isoDateFormatter stringFromDate:self.testDate.now];

    NSDictionary *expectedPayload = @{
        @"attributes" : @[
            @{
                @"action" : @"remove",
                @"timestamp" : timestamp,
                @"key" : @"game",
            }
        ]
    };

    UAAttributeMutations *mutations = [UAAttributeMutations mutations];

    [mutations setString:@"space" forAttribute:@"game"];
    [mutations setString:@"goose" forAttribute:@"game"];
    [mutations removeAttribute:@"game"];

    UAAttributePendingMutations *pendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:mutations
                                                                                                          date:self.testDate];

    pendingMutations = [UAAttributePendingMutations collapseMutations:@[pendingMutations]];

    XCTAssertEqualObjects(pendingMutations.payload, expectedPayload);
}

/**
 Test adding once then removing twice mutation results in a remove
*/
-(void)testAddRemoveRemove {
    NSDateFormatter *isoDateFormatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
    NSString *timestamp = [isoDateFormatter stringFromDate:self.testDate.now];

    NSDictionary *expectedPayload = @{
        @"attributes" : @[
            @{
                @"action" : @"remove",
                @"timestamp" : timestamp,
                @"key" : @"game",
            }
        ]
    };

    UAAttributeMutations *mutations = [UAAttributeMutations mutations];

    [mutations setString:@"space" forAttribute:@"game"];
    [mutations removeAttribute:@"game"];
    [mutations removeAttribute:@"game"];

    UAAttributePendingMutations *pendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:mutations
                                                                                                          date:self.testDate];

    pendingMutations = [UAAttributePendingMutations collapseMutations:@[pendingMutations]];

    XCTAssertEqualObjects(pendingMutations.payload, expectedPayload);
}

/**
 Test removing once then adding  mutation results in a remove
*/
-(void)testRemoveAdd {
    NSDateFormatter *isoDateFormatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    self.testDate = [[UATestDate alloc] initWithAbsoluteTime:[NSDate date]];
    NSString *timestamp = [isoDateFormatter stringFromDate:self.testDate.now];

    NSDictionary *expectedPayload = @{
        @"attributes" : @[
            @{
              @"action" : @"set",
              @"key" : @"game",
              @"timestamp" : timestamp,
              @"value" : @"space"
           },
        ]
    };

    UAAttributeMutations *mutations = [UAAttributeMutations mutations];

    [mutations removeAttribute:@"game"];
    [mutations setString:@"space" forAttribute:@"game"];

    UAAttributePendingMutations *pendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:mutations
                                                                                                          date:self.testDate];

    pendingMutations = [UAAttributePendingMutations collapseMutations:@[pendingMutations]];

    XCTAssertEqualObjects(pendingMutations.payload, expectedPayload);
}

@end
