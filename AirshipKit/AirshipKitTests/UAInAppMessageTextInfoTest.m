/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageTextInfo.h"

@interface UAInAppMessageTextInfoTest : XCTestCase

@end

@implementation UAInAppMessageTextInfoTest

- (void)testTextInfo {
    UAInAppMessageTextInfo *fromBuilderTextInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.alignment = NSTextAlignmentCenter;
        builder.color = [UIColor redColor];
        builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        builder.size = 11;
    }];
    
    UAInAppMessageTextInfo *fromJSONTextInfo = [UAInAppMessageTextInfo textInfoWithJSON:@{@"alignment" : UAInAppMessageTextInfoAlignmentCenterValue,
                                                                                          @"color" : @"#FFFF0000",
                                                                                          @"size" : @11,
                                                                                          @"style" :     @[@"bold",
                                                                                                           @"italic",
                                                                                                           @"underline"],
                                                                                          @"text" : @"text",
                                                                                          }
                                                                                  error:nil];
    
    NSDictionary *JSONFromBuilderTextInfo = [UAInAppMessageTextInfo JSONWithTextInfo:fromBuilderTextInfo];
    NSDictionary *JSONFromJSONTextInfo = [UAInAppMessageTextInfo JSONWithTextInfo:fromJSONTextInfo];

    // Test isEqual and hashing
    XCTAssertTrue([fromBuilderTextInfo isEqual:fromJSONTextInfo]);
    XCTAssertEqual(fromBuilderTextInfo.hash, fromJSONTextInfo.hash);
    
    // Test conversion to JSON
    XCTAssertEqualObjects(JSONFromBuilderTextInfo, JSONFromJSONTextInfo);
}

@end
