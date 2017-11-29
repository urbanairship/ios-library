/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageButtonInfo.h"

@interface UAInAppMessageButtonInfoTest : XCTestCase

@end

@implementation UAInAppMessageButtonInfoTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testButtonInfo {
    UAInAppMessageButtonInfo *fromBuilderButtonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"text";
            builder.alignment = UAInAppMessageTextInfoAlignmentCenter;
            builder.color = @"hexcolor";
            builder.styles = @[UAInAppMessageTextInfoStyleBold, UAInAppMessageTextInfoStyleItalic, UAInAppMessageTextInfoStyleUnderline];
            builder.size = 11;
        }];

        builder.identifier = @"identifier";
        builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        builder.borderRadius = 11;
        builder.backgroundColor = @"hexcolor";
        builder.borderColor = @"hexcolor";
        builder.actions = @{@"+^t":@"test"};
    }];

    NSDictionary *JSONFromBuilderButtonInfo = [UAInAppMessageButtonInfo JSONWithButtonInfo:fromBuilderButtonInfo];
    UAInAppMessageButtonInfo *fromJSONButtonInfo = [UAInAppMessageButtonInfo buttonInfoWithJSON:JSONFromBuilderButtonInfo error:nil];
    NSDictionary *JSONFromJSONButtonInfo = [UAInAppMessageButtonInfo JSONWithButtonInfo:fromJSONButtonInfo];

    // Test isEqual and hashing
    XCTAssertTrue([fromBuilderButtonInfo isEqual:fromJSONButtonInfo] == YES);
    XCTAssertEqual(fromBuilderButtonInfo.hash, fromJSONButtonInfo.hash);

    // Test conversion to JSON
    XCTAssertEqualObjects(JSONFromBuilderButtonInfo, JSONFromJSONButtonInfo);
    XCTAssertTrue([JSONFromBuilderButtonInfo isEqual:JSONFromJSONButtonInfo] == YES);
}

@end

