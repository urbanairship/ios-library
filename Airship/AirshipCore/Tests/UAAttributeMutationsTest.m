/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UADate.h"
#import "UAUtils+Internal.h"
#import "UAAttributeMutations+Internal.h"

@interface UAAttributeMutationsTest : UABaseTest
@end

@implementation UAAttributeMutationsTest

/**
 Test add and remove operations on a mutations object result in a payload matching the applied operations
*/
-(void)testMutationsPayload {
    NSArray *expectedMutations = @[
        @{
            @"action" : @"set",
            @"key" : @"jam",
            @"value" : @"space"
        },
        @{
            @"action" : @"set",
            @"key" : @"game",
            @"value" : @"goose"
        },
        @{
            @"action" : @"set",
            @"key" : @"luggage",
            @"value" : @(12345)
        },
        @{
            @"action" : @"set",
            @"key" : @"not_quite_pi",
            @"value" : @(3.14)
        },
        @{
            @"action" : @"set",
            @"key" : @"millenium",
            @"value" : @"2000-01-01T00:00:00"
        },
        @{
            @"action" : @"set",
            @"key" : @"before-millenium",
            @"value" : @"1999-12-31T23:59:59"
        },
        @{
            @"action" : @"remove",
            @"key" : @"game",
        }
    ];

    UAAttributeMutations *mutations = [UAAttributeMutations mutations];

    [mutations setString:@"space" forAttribute:@"jam"];
    [mutations setString:@"goose" forAttribute:@"game"];
    [mutations setNumber:@(12345) forAttribute:@"luggage"];
    [mutations setNumber:@(3.14) forAttribute:@"not_quite_pi"];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd";
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDate *millenium = [dateFormatter dateFromString:@"2000-01-01"];
    [mutations setDate:millenium forAttribute:@"millenium"];
    
    NSDate *beforeMillenium = [NSDate dateWithTimeInterval:-1 sinceDate:millenium];
    [mutations setDate:beforeMillenium forAttribute:@"before-millenium"];
    
    [mutations removeAttribute:@"game"];

    XCTAssertEqualObjects(mutations.mutationsPayload, expectedMutations);
}

// Test attribute keys and values only accept setting strings less than or equal to 1024 characters
- (void)testLongAttributeStringsSet {
    UAAttributeMutations *stringNormalizationMutations = [UAAttributeMutations mutations];

    NSString *tooLongStringSet = [@"O" stringByPaddingToLength:1025 withString:@"O" startingAtIndex:0];
    NSString *justRightStringSet =  [@"O" stringByPaddingToLength:1023 withString:@"O" startingAtIndex:0];

    NSArray *expectedMutationsPayloadTooLong = @[];

    NSArray *expectedMutationsPayloadJustRight = @[@{
            @"action" : @"set",
            @"key" : justRightStringSet,
            @"value" : justRightStringSet
        }
    ];

    [stringNormalizationMutations setString:tooLongStringSet forAttribute:tooLongStringSet];
    XCTAssertEqualObjects(stringNormalizationMutations.mutationsPayload, expectedMutationsPayloadTooLong);
    [stringNormalizationMutations setString:justRightStringSet forAttribute:justRightStringSet];
    XCTAssertEqualObjects(stringNormalizationMutations.mutationsPayload, expectedMutationsPayloadJustRight);
}

// Test attribute keys and values only accept removing strings less than or equal to 1024 characters
- (void)testLongAttributeStringsRemove {
    UAAttributeMutations *stringNormalizationMutations = [UAAttributeMutations mutations];

    NSString *tooLongStringRemove = [@"E" stringByPaddingToLength:1025 withString:@"E" startingAtIndex:0];
    NSString *justRightStringRemove =  [@"E" stringByPaddingToLength:1023 withString:@"E" startingAtIndex:0];

    NSArray *expectedMutationsPayloadTooLong = @[];

    NSArray *expectedMutationsPayloadJustRight = @[@{
            @"action" : @"remove",
            @"key" : justRightStringRemove,
        }
    ];

    [stringNormalizationMutations removeAttribute:tooLongStringRemove];
    XCTAssertEqualObjects(stringNormalizationMutations.mutationsPayload, expectedMutationsPayloadTooLong);
    [stringNormalizationMutations removeAttribute:justRightStringRemove];
    XCTAssertEqualObjects(stringNormalizationMutations.mutationsPayload, expectedMutationsPayloadJustRight);
}

@end
