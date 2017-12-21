/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UABaseTest.h"
#import "UAInAppMessageButtonInfo+Internal.h"

@interface UAInAppMessageButtonInfoTest : UABaseTest

@end

@implementation UAInAppMessageButtonInfoTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testButtonInfo {
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
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

    UAInAppMessageButtonInfo *fromJSON = [UAInAppMessageButtonInfo buttonInfoWithJSON:[buttonInfo toJSON] error:nil];

    // Test isEqual and hashing
    XCTAssertEqualObjects(buttonInfo, fromJSON);
    XCTAssertEqual(buttonInfo.hash, fromJSON.hash);
}
- (void)testMissingLabel {
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.identifier = @"identifier";
        builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        builder.borderRadius = 11;
        builder.backgroundColor = [UIColor redColor];
        builder.borderColor = [UIColor redColor];
        builder.actions = @{@"+^t":@"test"};
    }];

   XCTAssertNil(buttonInfo);
}

- (void)testMissingID {
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"text";
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            builder.size = 11;
        }];

        builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        builder.borderRadius = 11;
        builder.backgroundColor = [UIColor redColor];
        builder.borderColor = [UIColor redColor];
        builder.actions = @{@"+^t":@"test"};
    }];

    XCTAssertNil(buttonInfo);
}

@end

