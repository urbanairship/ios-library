/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UADate+Internal.h"
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
            @"action" : @"remove",
            @"key" : @"game",
        }
    ];

    UAAttributeMutations *mutations = [UAAttributeMutations mutations];

    [mutations setString:@"space" forAttribute:@"jam"];
    [mutations setString:@"goose" forAttribute:@"game"];
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
