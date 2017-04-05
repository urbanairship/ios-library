/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "UATagUtils+Internal.h"

@interface UATagUtilsTest : XCTestCase
@end

@implementation UATagUtilsTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Tests tag normalization when tag includes whitespace
 */
- (void)testNormalizeTagsWhitespaceRemoval {
    NSArray *tags = @[@"   tag-one   ", @"tag-two   "];
    NSArray *tagsNoSpaces = @[@"tag-one", @"tag-two"];

    XCTAssertEqualObjects(tagsNoSpaces, [UATagUtils normalizeTags:tags], @"whitespace was trimmed from tags");
}

/**
 * Tests tag normalization when tag has maximum acceptable length
 */
- (void)testNormalizeTagsMaxTagSize {
    NSArray *tags = @[[@"" stringByPaddingToLength:127 withString: @"." startingAtIndex:0]];

    XCTAssertEqualObjects(tags, [UATagUtils normalizeTags:tags], @"tag with 127 characters should set");
}

/**
 * Tests tag normalization when tag has greater than maximum acceptable length
 */
- (void)testNormalizeTagsOverMaxTagSizeRemoval {
    NSArray *tags = @[[@"" stringByPaddingToLength:128 withString: @"." startingAtIndex:0]];

    XCTAssertNotEqualObjects(tags, [UATagUtils normalizeTags:tags], @"tag with 128 characters should not set");
}
@end
