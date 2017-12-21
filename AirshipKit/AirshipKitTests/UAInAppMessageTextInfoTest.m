/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageTextInfo+Internal.h"
#import "UABaseTest.h"

@interface UAInAppMessageTextInfoTest : UABaseTest

@end

@implementation UAInAppMessageTextInfoTest

- (void)testTextInfo {
    UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.alignment = NSTextAlignmentCenter;
        builder.color = [UIColor redColor];
        builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        builder.size = 11;
    }];
    
    UAInAppMessageTextInfo *fromJSON = [UAInAppMessageTextInfo textInfoWithJSON:[textInfo toJson] error:nil];

    // Test isEqual and hashing
    XCTAssertEqualObjects(textInfo, fromJSON);
    XCTAssertEqual(textInfo.hash, fromJSON.hash);
}

- (void)testMissingText {
    UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.alignment = NSTextAlignmentCenter;
        builder.color = [UIColor redColor];
        builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        builder.size = 11;
    }];

    XCTAssertNil(textInfo);
}

@end
