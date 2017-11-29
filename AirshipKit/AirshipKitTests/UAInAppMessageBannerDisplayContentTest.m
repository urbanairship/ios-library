/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageBannerDisplayContent.h"

@interface UAInAppMessageBannerDisplayContentTest : XCTestCase

@end

@implementation UAInAppMessageBannerDisplayContentTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testBannerDisplayContent {
    UAInAppMessageBannerDisplayContent *fromBuilderBannerDisplayContent = [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder * _Nonnull builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"heading";
            builder.alignment = UAInAppMessageTextInfoAlignmentCenter;
            builder.color = @"hexcolor";
            builder.styles = @[UAInAppMessageTextInfoStyleBold, UAInAppMessageTextInfoStyleItalic, UAInAppMessageTextInfoStyleUnderline];
            builder.size = 11;
        }];
        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body";
            builder.alignment = UAInAppMessageTextInfoAlignmentCenter;
            builder.color = @"hexcolor";
            builder.styles = @[UAInAppMessageTextInfoStyleBold, UAInAppMessageTextInfoStyleItalic, UAInAppMessageTextInfoStyleUnderline];
            builder.size = 11;
        }];;
        builder.media = [UAInAppMessageMediaInfo mediaInfoWithBuilderBlock:^(UAInAppMessageMediaInfoBuilder * _Nonnull builder) {
            builder.url = @"testurl";
            builder.type = UAInAppMessageMediaInfoTypeYouTube;
        }];
        builder.buttons = @[[UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"button1";
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
        }], [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"button2";
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
        }]];

        builder.buttonLayout = UAInAppMessageButtonLayoutStacked;
        builder.placement = UAInAppMessageBannerPlacementTop;
        builder.contentLayout = UAInAppMessageBannerContentLayoutMediaLeft;
        builder.duration = 11;
        builder.backgroundColor = @"hexcolor";
        builder.dismissButtonColor = @"hexcolor";;
        builder.borderRadius = 11;
        builder.actions = @{@"^+t": @"sometag"};
    }];

    NSDictionary *JSONFromBuilderBannerDisplayContent = [UAInAppMessageBannerDisplayContent JSONWithBannerDisplayContent:fromBuilderBannerDisplayContent];
    UAInAppMessageBannerDisplayContent *fromJSONBannerDisplayContent = [UAInAppMessageBannerDisplayContent bannerDisplayContentWithJSON:JSONFromBuilderBannerDisplayContent error:nil];
    NSDictionary *JSONFromJSONBannerDisplayContent = [UAInAppMessageBannerDisplayContent JSONWithBannerDisplayContent:fromJSONBannerDisplayContent];

    // Test isEqual and hashing
    XCTAssertTrue([fromBuilderBannerDisplayContent isEqual:fromJSONBannerDisplayContent] == YES);
    XCTAssertEqual(fromBuilderBannerDisplayContent.hash, fromJSONBannerDisplayContent.hash);

    // Test conversion to JSON
    XCTAssertEqualObjects(JSONFromBuilderBannerDisplayContent, JSONFromJSONBannerDisplayContent);
    XCTAssertTrue([JSONFromBuilderBannerDisplayContent isEqual:JSONFromJSONBannerDisplayContent] == YES);
}

@end
