/* Copyright 2010-2019 Urban Airship and Contributors */

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
    
    UAInAppMessageTextInfo *fromJSON = [UAInAppMessageTextInfo textInfoWithJSON:[textInfo toJSON] error:nil];

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

- (void)testExtend {
    UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.alignment = NSTextAlignmentCenter;
        builder.color = [UIColor redColor];
        builder.fontFamilies = @[@"sans-serif"];
        builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        builder.size = 11;
    }];

    UAInAppMessageTextInfo *newInfo = [textInfo extend:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"new text";
    }];

    XCTAssertNotNil(newInfo);
    XCTAssertFalse([newInfo isEqual:textInfo]);
    XCTAssertEqual(newInfo.alignment, textInfo.alignment);
    XCTAssertEqualObjects(newInfo.color, textInfo.color);
    XCTAssertEqualObjects(newInfo.fontFamilies, textInfo.fontFamilies);
    XCTAssertEqual(newInfo.style, textInfo.style);
    XCTAssertEqual(newInfo.size, textInfo.size);
    XCTAssertEqualObjects(newInfo.text, @"new text");
}

@end
