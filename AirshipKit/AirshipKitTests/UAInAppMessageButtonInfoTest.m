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
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            builder.size = 11;
        }];

        builder.identifier = @"identifier";
        builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        builder.borderRadius = 11;
        builder.backgroundColor = [UIColor redColor];
        builder.borderColor = [UIColor redColor];
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
}

@end

