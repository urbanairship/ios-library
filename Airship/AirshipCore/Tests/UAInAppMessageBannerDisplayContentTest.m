/* Copyright Airship and Contributors */

#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UABaseTest.h"
#import "UAInAppMessageMediaInfo.h"

@interface UAInAppMessageBannerDisplayContentTest : UABaseTest

@end

@implementation UAInAppMessageBannerDisplayContentTest

- (void)testTooManyButtons {
    UAInAppMessageBannerDisplayContent *twoButtons =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
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
            builder.backgroundColor = [UIColor redColor]; // red
            builder.identifier = @"button";
        }];

        builder.buttons = @[button, button];
    }];

    XCTAssertTrue(twoButtons.buttons.count == 2);

    UAInAppMessageBannerDisplayContent *threeButtons =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
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
            builder.backgroundColor = [UIColor redColor]; // red
            builder.identifier = @"button";
        }];

        // 6 buttons with max buttons of 5
        builder.buttons = @[button, button, button];
    }];

    // Should not build with button count of 6
    XCTAssertNil(threeButtons);
}

- (void)testValidButtonLayout {
    UAInAppMessageBannerDisplayContent *bannerWithJoinedButtons =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;
    }];

    XCTAssertEqual(bannerWithJoinedButtons.buttonLayout, UAInAppMessageButtonLayoutTypeJoined);

    UAInAppMessageBannerDisplayContent *bannerWithSeparateButtons =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
    }];

    XCTAssertEqual(bannerWithSeparateButtons.buttonLayout, UAInAppMessageButtonLayoutTypeSeparate);

    UAInAppMessageBannerDisplayContent *bannerWithStackedButtons =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.buttonLayout = UAInAppMessageButtonLayoutTypeStacked;
    }];

    XCTAssertEqual(bannerWithStackedButtons.buttonLayout, UAInAppMessageButtonLayoutTypeStacked);
}

- (void)testValidMediaType {
    UAInAppMessageBannerDisplayContent *bannerWithImage =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithURL:@"url string"
                                               contentDescription:@"description"
                                                             type:UAInAppMessageMediaInfoTypeImage];
    }];

    XCTAssertEqual(bannerWithImage.media.type, UAInAppMessageMediaInfoTypeImage);

    UAInAppMessageBannerDisplayContent *bannerWithVideo =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithURL:@"url string"
                                               contentDescription:@"description"
                                                             type:UAInAppMessageMediaInfoTypeVideo];
    }];

    XCTAssertNil(bannerWithVideo);

    UAInAppMessageBannerDisplayContent *bannerWithYouTube =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithURL:@"url string"
                                               contentDescription:@"description"
                                                             type:UAInAppMessageMediaInfoTypeYouTube];

    }];

    XCTAssertNil(bannerWithYouTube);
}

- (void)testNoHeaderOrBody {
    UAInAppMessageBannerDisplayContent *headerAndBody =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];
    }];

    XCTAssertEqualObjects(headerAndBody.heading.text, @"headline content");
    XCTAssertEqualObjects(headerAndBody.body.text, @"body content");

    UAInAppMessageBannerDisplayContent *noHeader =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];
    }];

    XCTAssertNil(noHeader.heading);
    XCTAssertEqualObjects(noHeader.body.text, @"body content");

    UAInAppMessageBannerDisplayContent *noBody =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];
    }];

    XCTAssertEqualObjects(noBody.heading.text, @"headline content");
    XCTAssertNil(noBody.body);

    UAInAppMessageBannerDisplayContent *noHeaderOrBody =  [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
    }];

    XCTAssertNil(noHeaderOrBody);
}

- (void)testBannerDisplayContent {
    UAInAppMessageBannerDisplayContent *banner = [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder * _Nonnull builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"heading";
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            builder.sizePoints = 11;
        }];
        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body";
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic;
            builder.sizePoints = 11;
        }];;
        builder.media = [UAInAppMessageMediaInfo mediaInfoWithURL:@"testurl"
                                               contentDescription:@"description"
                                                             type:UAInAppMessageMediaInfoTypeImage];
        builder.buttons = @[[UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"button1";
                builder.alignment = NSTextAlignmentCenter;
                builder.color = [UIColor redColor];
                builder.style = UAInAppMessageTextInfoStyleUnderline;
                builder.sizePoints = 11;
            }];

            builder.identifier = @"identifier";
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
            builder.borderRadiusPoints = 11;
            builder.backgroundColor = [UIColor redColor];
            builder.borderColor = [UIColor redColor];
            builder.actions = @{@"+^t":@"test"};
        }], [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"button2";
                builder.alignment = NSTextAlignmentCenter;
                builder.color = [UIColor redColor];
                builder.sizePoints = 11;
            }];

            builder.identifier = @"identifier";
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
            builder.borderRadiusPoints = 11.1;
            builder.backgroundColor = [UIColor redColor];
            builder.borderColor = [UIColor redColor];
            builder.actions = @{@"+^t":@"test"};
        }]];

        builder.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        builder.placement = UAInAppMessageBannerPlacementTop;
        builder.contentLayout = UAInAppMessageBannerContentLayoutTypeMediaLeft;
        builder.durationSeconds = 11;
        builder.dismissButtonColor = [UIColor redColor];
        builder.borderRadiusPoints = 11.2;
        builder.actions = @{@"^+t": @"sometag"};
    }];

    UAInAppMessageBannerDisplayContent *fromJSON = [UAInAppMessageBannerDisplayContent displayContentWithJSON:[banner toJSON] error:nil];

    // Test isEqual and hashing
    XCTAssertEqualObjects(banner, fromJSON);
    XCTAssertEqual(banner.hash, fromJSON.hash);
}

- (void)testExtend {
    UAInAppMessageBannerDisplayContent *banner = [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder * _Nonnull builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"heading";
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            builder.sizePoints = 11;
        }];
        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body";
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic;
            builder.sizePoints = 11;
        }];;
        builder.media = [UAInAppMessageMediaInfo mediaInfoWithURL:@"testurl"
                                               contentDescription:@"description"
                                                             type:UAInAppMessageMediaInfoTypeImage];
        builder.buttons = @[[UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"button1";
                builder.alignment = NSTextAlignmentCenter;
                builder.color = [UIColor redColor];
                builder.style = UAInAppMessageTextInfoStyleUnderline;
                builder.sizePoints = 11;
            }];

            builder.identifier = @"identifier";
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
            builder.borderRadiusPoints = 11.3;
            builder.backgroundColor = [UIColor redColor];
            builder.borderColor = [UIColor redColor];
            builder.actions = @{@"+^t":@"test"};
        }], [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"button2";
                builder.alignment = NSTextAlignmentCenter;
                builder.color = [UIColor redColor];
                builder.sizePoints = 11;
            }];

            builder.identifier = @"identifier";
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
            builder.borderRadiusPoints = 11.4;
            builder.backgroundColor = [UIColor redColor];
            builder.borderColor = [UIColor redColor];
            builder.actions = @{@"+^t":@"test"};
        }]];

        builder.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        builder.placement = UAInAppMessageBannerPlacementTop;
        builder.contentLayout = UAInAppMessageBannerContentLayoutTypeMediaLeft;
        builder.durationSeconds = 11;
        builder.dismissButtonColor = [UIColor redColor];
        builder.borderRadiusPoints = 11.5;
        builder.actions = @{@"^+t": @"sometag"};
    }];

    UAInAppMessageBannerDisplayContent *newBanner = [banner extend:^(UAInAppMessageBannerDisplayContentBuilder * _Nonnull builder) {
        builder.durationSeconds = 22;
    }];

    XCTAssertNotNil(newBanner);
    XCTAssertFalse([newBanner isEqual:banner]);
    XCTAssertEqualObjects(newBanner.backgroundColor, banner.backgroundColor);
    XCTAssertEqualObjects(newBanner.dismissButtonColor, banner.dismissButtonColor);
    XCTAssertEqual(newBanner.borderRadiusPoints, banner.borderRadiusPoints);
    XCTAssertEqualObjects(newBanner.actions, banner.actions);
    XCTAssertEqual(newBanner.durationSeconds, 22);
}

@end
