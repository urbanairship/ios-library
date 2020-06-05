/* Copyright Airship and Contributors */

#import "UAInAppMessageTextInfo+Internal.h"
#import "UABaseTest.h"
#import "UAColorUtils.h"

@interface UAInAppMessageTextInfoTest : UABaseTest

@end

@implementation UAInAppMessageTextInfoTest

- (void)testMinimalBannerDisplayContent {
    UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
    }];
    
    XCTAssertNil(textInfo);
    
    textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"hi there";
    }];
    
    XCTAssertNotNil(textInfo);
}

- (void)testDefaultBannerDisplayContent {
    UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"hi there";
    }];
    
    XCTAssertEqualObjects([UAColorUtils hexStringWithColor:textInfo.color], [UAColorUtils hexStringWithColor:[UIColor blackColor]]);
    XCTAssertEqual(textInfo.sizePoints, 14);
    XCTAssertEqual(textInfo.alignment, UAInAppMessageTextInfoAlignmentNone);
    
}

- (void)testTextInfo {
    UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.alignment = UAInAppMessageTextInfoAlignmentCenter;
        builder.color = [UIColor redColor];
        builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        builder.sizePoints = 11;
    }];
    
    UAInAppMessageTextInfo *fromJSON = [UAInAppMessageTextInfo textInfoWithJSON:[textInfo toJSON] error:nil];

    // Test isEqual and hashing
    XCTAssertEqualObjects(textInfo, fromJSON);
    XCTAssertEqual(textInfo.hash, fromJSON.hash);
}

- (void)testMissingText {
    UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.alignment = UAInAppMessageTextInfoAlignmentCenter;
        builder.color = [UIColor redColor];
        builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        builder.sizePoints = 11;
    }];

    XCTAssertNil(textInfo);
}

- (void)testExtend {
    UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.alignment = UAInAppMessageTextInfoAlignmentCenter;
        builder.color = [UIColor redColor];
        builder.fontFamilies = @[@"sans-serif"];
        builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        builder.sizePoints = 11;
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
    XCTAssertEqual(newInfo.sizePoints, textInfo.sizePoints);
    XCTAssertEqualObjects(newInfo.text, @"new text");
}

@end
