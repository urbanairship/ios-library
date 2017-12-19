/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageBannerDisplayContent.h"
#import "UABaseTest.h"
#import "UAInAppMessageMediaInfo.h"

@interface UAInAppMessageBannerDisplayContentTest : UABaseTest

@end

@implementation UAInAppMessageBannerDisplayContentTest

- (void)testTooManyButtons {
    UAInAppMessageBannerDisplayContent *twoButtons =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];;

        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];

        UAInAppMessageButtonInfo *button = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Dismiss";
            }];
            builder.backgroundColor = @"#ff0000"; // red
        }];

        builder.buttons = @[button, button];
    }];

    XCTAssertTrue(twoButtons.buttons.count == 2);

    UAInAppMessageBannerDisplayContent *threeButtons =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];;

        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];

        UAInAppMessageButtonInfo *button = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Dismiss";
            }];
            builder.backgroundColor = @"#ff0000"; // red
        }];

        // 6 buttons with max buttons of 5
        builder.buttons = @[button, button, button];
    }];

    // Should not build with button count of 6
    XCTAssertNil(threeButtons);
}

- (void)testValidButtonLayout {
    UAInAppMessageBannerDisplayContent *bannerWithJoinedButtons =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.buttonLayout = UAInAppMessageButtonLayoutJoined;
    }];

    XCTAssertEqual(bannerWithJoinedButtons.buttonLayout, UAInAppMessageButtonLayoutJoined);

    UAInAppMessageBannerDisplayContent *bannerWithSeparateButtons =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.buttonLayout = UAInAppMessageButtonLayoutSeparate;
    }];

    XCTAssertEqual(bannerWithSeparateButtons.buttonLayout, UAInAppMessageButtonLayoutSeparate);

    UAInAppMessageBannerDisplayContent *bannerWithStackedButtons =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.buttonLayout = UAInAppMessageButtonLayoutStacked;
    }];

    XCTAssertNil(bannerWithStackedButtons);
}

- (void)testValidMediaType {
    UAInAppMessageBannerDisplayContent *bannerWithImage =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithBuilderBlock:^(UAInAppMessageMediaInfoBuilder * _Nonnull builder) {
            builder.type = UAInAppMessageMediaInfoTypeImage;
            builder.url = @"url string";
        }];

    }];

    XCTAssertEqualObjects(bannerWithImage.media.type, UAInAppMessageMediaInfoTypeImage);

    UAInAppMessageBannerDisplayContent *bannerWithVideo =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithBuilderBlock:^(UAInAppMessageMediaInfoBuilder * _Nonnull builder) {
            builder.type = UAInAppMessageMediaInfoTypeVideo;
            builder.url = @"url string";
        }];

    }];

    XCTAssertNil(bannerWithVideo);

    UAInAppMessageBannerDisplayContent *bannerWithYouTube =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithBuilderBlock:^(UAInAppMessageMediaInfoBuilder * _Nonnull builder) {
            builder.type = UAInAppMessageMediaInfoTypeYouTube;
            builder.url = @"url string";
        }];

    }];

    XCTAssertNil(bannerWithYouTube);
}

- (void)testNoHeaderOrBody {
    UAInAppMessageBannerDisplayContent *headerAndBody =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];
    }];

    XCTAssertEqualObjects(headerAndBody.heading.text, @"headline content");
    XCTAssertEqualObjects(headerAndBody.body.text, @"body content");

    UAInAppMessageBannerDisplayContent *noHeader =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];
    }];

    XCTAssertNil(noHeader.heading);
    XCTAssertEqualObjects(noHeader.body.text, @"body content");

    UAInAppMessageBannerDisplayContent *noBody =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];
    }];

    XCTAssertEqualObjects(noBody.heading.text, @"headline content");
    XCTAssertNil(noBody.body);

    UAInAppMessageBannerDisplayContent *noHeaderOrBody =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
    }];

    XCTAssertNil(noHeaderOrBody);
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
            builder.type = UAInAppMessageMediaInfoTypeImage;
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

        builder.buttonLayout = UAInAppMessageButtonLayoutSeparate;
        builder.placement = UAInAppMessageBannerPlacementTop;
        builder.contentLayout = UAInAppMessageBannerContentLayoutMediaLeft;
        builder.duration = 11;
        builder.backgroundColor = @"hexcolor";
        builder.dismissButtonColor = @"hexcolor";;
        builder.borderRadius = 11;
        builder.actions = @{@"^+t": @"sometag"};
    }];

    NSDictionary *JSONFromBuilderBannerDisplayContent = [fromBuilderBannerDisplayContent toJsonValue];
    UAInAppMessageBannerDisplayContent *fromJSONBannerDisplayContent = [UAInAppMessageBannerDisplayContent bannerDisplayContentWithJSON:JSONFromBuilderBannerDisplayContent error:nil];
    NSDictionary *JSONFromJSONBannerDisplayContent = [fromJSONBannerDisplayContent toJsonValue];

    // Test isEqual and hashing
    XCTAssertTrue([fromBuilderBannerDisplayContent isEqual:fromJSONBannerDisplayContent] == YES);
    XCTAssertEqual(fromBuilderBannerDisplayContent.hash, fromJSONBannerDisplayContent.hash);

    // Test conversion to JSON
    XCTAssertEqualObjects(JSONFromBuilderBannerDisplayContent, JSONFromJSONBannerDisplayContent);
}

@end
