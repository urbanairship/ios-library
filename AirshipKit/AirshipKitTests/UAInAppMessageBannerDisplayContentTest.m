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
            builder.backgroundColor = [UIColor redColor]; // red
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
            builder.backgroundColor = [UIColor redColor]; // red
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

        builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;
    }];

    XCTAssertEqual(bannerWithJoinedButtons.buttonLayout, UAInAppMessageButtonLayoutTypeJoined);

    UAInAppMessageBannerDisplayContent *bannerWithSeparateButtons =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
    }];

    XCTAssertEqual(bannerWithSeparateButtons.buttonLayout, UAInAppMessageButtonLayoutTypeSeparate);

    UAInAppMessageBannerDisplayContent *bannerWithStackedButtons =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.buttonLayout = UAInAppMessageButtonLayoutTypeStacked;
    }];

    XCTAssertNil(bannerWithStackedButtons);
}

- (void)testValidMediaType {
    UAInAppMessageBannerDisplayContent *bannerWithImage =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithURL:@"url string"
                                               contentDescription:@"description"
                                                             type:UAInAppMessageMediaInfoTypeImage];
    }];

    XCTAssertEqual(bannerWithImage.media.type, UAInAppMessageMediaInfoTypeImage);

    UAInAppMessageBannerDisplayContent *bannerWithVideo =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithURL:@"url string"
                                               contentDescription:@"description"
                                                             type:UAInAppMessageMediaInfoTypeVideo];
    }];

    XCTAssertNil(bannerWithVideo);

    UAInAppMessageBannerDisplayContent *bannerWithYouTube =  [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
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
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            builder.size = 11;
        }];
        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body";
            builder.alignment = NSTextAlignmentCenter;
            builder.color = [UIColor redColor];
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic;
            builder.size = 11;
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
                builder.size = 11;
            }];

            builder.identifier = @"identifier";
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
            builder.borderRadius = 11;
            builder.backgroundColor = [UIColor redColor];
            builder.borderColor = [UIColor redColor];
            builder.actions = @{@"+^t":@"test"};
        }], [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"button2";
                builder.alignment = NSTextAlignmentCenter;
                builder.color = [UIColor redColor];
                builder.size = 11;
            }];

            builder.identifier = @"identifier";
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
            builder.borderRadius = 11;
            builder.backgroundColor = [UIColor redColor];
            builder.borderColor = [UIColor redColor];
            builder.actions = @{@"+^t":@"test"};
        }]];

        builder.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        builder.placement = UAInAppMessageBannerPlacementTop;
        builder.contentLayout = UAInAppMessageBannerContentLayoutTypeMediaLeft;
        builder.duration = 11;
        builder.dismissButtonColor = [UIColor redColor];
        builder.borderRadius = 11;
        builder.actions = @{@"^+t": @"sometag"};
    }];

    NSDictionary *JSONFromBuilderBannerDisplayContent = [fromBuilderBannerDisplayContent toJsonValue];
    XCTAssertNotNil(JSONFromBuilderBannerDisplayContent);
    UAInAppMessageBannerDisplayContent *fromJSONBannerDisplayContent = [UAInAppMessageBannerDisplayContent bannerDisplayContentWithJSON:JSONFromBuilderBannerDisplayContent error:nil];
    XCTAssertNotNil(fromJSONBannerDisplayContent);

    // Test isEqual and hashing
    XCTAssertTrue([fromBuilderBannerDisplayContent isEqual:fromJSONBannerDisplayContent]);
    XCTAssertEqual(fromBuilderBannerDisplayContent.hash, fromJSONBannerDisplayContent.hash);
}

@end
