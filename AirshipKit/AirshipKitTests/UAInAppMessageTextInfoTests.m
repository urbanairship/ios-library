/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageTextInfo.h"
#import "UAColorUtils+Internal.h"

@interface UAInAppMessageTextInfoTests : UABaseTest

@end

@implementation UAInAppMessageTextInfoTests

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
    XCTAssertEqual(textInfo.size, 14);
    XCTAssertEqual(textInfo.alignment, UAInAppMessageTextInfoAlignmentNone);
    
}

@end
