/* Copyright 2018 Urban Airship and Contributors */

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
            builder.sizePoints = 11;
        }];

        builder.identifier = [@"" stringByPaddingToLength:UAInAppMessageButtonInfoIDLimit withString:@"ID" startingAtIndex:0];
        builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        builder.borderRadiusPoints = 11.00000010001009;
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
        builder.borderRadiusPoints = 11.2;
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
            builder.sizePoints = 11;
        }];

        builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        builder.borderRadiusPoints = 11.3;
        builder.backgroundColor = [UIColor redColor];
        builder.borderColor = [UIColor redColor];
        builder.actions = @{@"+^t":@"test"};
    }];

    XCTAssertNil(buttonInfo);
}

- (void)testEmptyID {
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"text";
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            builder.sizePoints = 11;
        }];

        builder.identifier = @"";
        builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        builder.borderRadiusPoints = 11.4;
        builder.backgroundColor = [UIColor redColor];
        builder.borderColor = [UIColor redColor];
        builder.actions = @{@"+^t":@"test"};

    }];

    XCTAssertNil(buttonInfo);
}

- (void)testExceedsMaxIDLength {
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"text";
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            builder.sizePoints = 11;
        }];

        builder.identifier = [@"" stringByPaddingToLength:UAInAppMessageButtonInfoIDLimit + 1 withString:@"YOLO" startingAtIndex:0];
        builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        builder.borderRadiusPoints = 11.5;
        builder.backgroundColor = [UIColor redColor];
        builder.borderColor = [UIColor redColor];
        builder.actions = @{@"+^t":@"test"};
    }];

    XCTAssertNil(buttonInfo);
}

- (void)testExtend {
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"text";
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            builder.sizePoints = 11;
        }];

        builder.identifier = [@"" stringByPaddingToLength:UAInAppMessageButtonInfoIDLimit withString:@"ID" startingAtIndex:0];
        builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        builder.borderRadiusPoints = 11.6;
        builder.backgroundColor = [UIColor redColor];
        builder.borderColor = [UIColor redColor];
        builder.actions = @{@"+^t":@"test"};
    }];

    UAInAppMessageButtonInfo *newInfo = [buttonInfo extend:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.actions = @{@"+^t":@"cool"};
    }];

    XCTAssertNotNil(newInfo);
    XCTAssertFalse([newInfo isEqual:buttonInfo]);
    XCTAssertEqualObjects(newInfo.label, buttonInfo.label);
    XCTAssertEqual(newInfo.behavior, buttonInfo.behavior);
    XCTAssertEqual(newInfo.borderRadiusPoints, buttonInfo.borderRadiusPoints);
    XCTAssertEqualObjects(newInfo.backgroundColor, buttonInfo.backgroundColor);
    XCTAssertEqualObjects(newInfo.borderColor, buttonInfo.borderColor);
    XCTAssertEqualObjects(newInfo.actions, @{@"+^t":@"cool"});
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (void)testBorderRadius {
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.borderRadius = 10;
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"text";
        }];
        builder.identifier = [@"" stringByPaddingToLength:UAInAppMessageButtonInfoIDLimit withString:@"ID" startingAtIndex:0];
    }];
    
    XCTAssertNotNil(buttonInfo);
    XCTAssertEqual(buttonInfo.borderRadius, 10);
    XCTAssertEqual(buttonInfo.borderRadiusPoints, 10);

    UAInAppMessageButtonInfo *fromJSON = [UAInAppMessageButtonInfo buttonInfoWithJSON:[buttonInfo toJSON] error:nil];
    XCTAssertEqualObjects(fromJSON,buttonInfo);
    
    buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.borderRadiusPoints = 10.5;
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"text";
        }];
        builder.identifier = [@"" stringByPaddingToLength:UAInAppMessageButtonInfoIDLimit withString:@"ID" startingAtIndex:0];
    }];
    
    XCTAssertNotNil(buttonInfo);
    XCTAssertEqual(buttonInfo.borderRadius, 10);
    XCTAssertEqual(buttonInfo.borderRadiusPoints, 10.5);
    
    fromJSON = [UAInAppMessageButtonInfo buttonInfoWithJSON:[buttonInfo toJSON] error:nil];
    XCTAssertEqualObjects(fromJSON,buttonInfo);
}
#pragma GCC diagnostic pop

@end

