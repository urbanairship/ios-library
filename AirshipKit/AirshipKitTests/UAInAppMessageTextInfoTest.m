/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageTextInfo.h"

@interface UAInAppMessageTextInfoTest : XCTestCase

@end

@implementation UAInAppMessageTextInfoTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testTextInfo {
    UAInAppMessageTextInfo *fromBuilderTextInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = @"text";
        builder.alignment = UAInAppMessageTextInfoAlignmentCenter;
        builder.color = @"hexcolor";
        builder.styles = @[UAInAppMessageTextInfoStyleBold, UAInAppMessageTextInfoStyleItalic, UAInAppMessageTextInfoStyleUnderline];
        builder.size = 11;
    }];
    
    UAInAppMessageTextInfo *fromJSONTextInfo = [UAInAppMessageTextInfo textInfoWithJSON:@{@"alignment" : UAInAppMessageTextInfoAlignmentCenter,
                                                                                          @"color" : @"hexcolor",
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
    XCTAssertTrue([fromBuilderTextInfo isEqual:fromJSONTextInfo] == YES);
    XCTAssertEqual(fromBuilderTextInfo.hash, fromJSONTextInfo.hash);
    
    // Test conversion to JSON
    XCTAssertEqualObjects(JSONFromBuilderTextInfo, JSONFromJSONTextInfo);
}

@end
