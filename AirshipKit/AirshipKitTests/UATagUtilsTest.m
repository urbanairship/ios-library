/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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
