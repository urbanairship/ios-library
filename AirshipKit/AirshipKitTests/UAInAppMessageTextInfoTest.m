/* Copyright 2010-2019 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageTextInfo+Internal.h"
#import "UABaseTest.h"
#import "UAColorUtils+Internal.h"

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
        builder.alignment = NSTextAlignmentCenter;
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
        builder.alignment = NSTextAlignmentCenter;
        builder.color = [UIColor redColor];
        builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        builder.sizePoints = 11;
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

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (void)testSize {
    UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.size = 11;
    }];
    
    XCTAssertNotNil(textInfo);
    XCTAssertEqual(textInfo.size, 11);
    XCTAssertEqual(textInfo.sizePoints, 11);
    
    UAInAppMessageTextInfo *fromJSON = [UAInAppMessageTextInfo textInfoWithJSON:[textInfo toJSON] error:nil];
    XCTAssertEqualObjects(fromJSON, textInfo);
    
    textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.sizePoints = 11.5;
    }];
    
    XCTAssertNotNil(textInfo);
    XCTAssertEqual(textInfo.size, 11);
    XCTAssertEqual(textInfo.sizePoints, 11.5);
    
    fromJSON = [UAInAppMessageTextInfo textInfoWithJSON:[textInfo toJSON] error:nil];
    XCTAssertEqualObjects(fromJSON, textInfo);
    
    UAInAppMessageTextInfo *textInfoFloatingPointAcceptableError = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.sizePoints = 11.50000001;
    }];
    
    XCTAssertEqualObjects(textInfo, textInfoFloatingPointAcceptableError);
    
    UAInAppMessageTextInfo *textInfoFloatingPointUnacceptableError = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.sizePoints = 11.52;
    }];
    
    XCTAssertNotEqualObjects(textInfo, textInfoFloatingPointUnacceptableError);

}
#pragma GCC diagnostic pop

@end
