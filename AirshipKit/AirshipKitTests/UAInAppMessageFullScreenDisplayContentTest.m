/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessage.h"
#import "UABaseTest.h"

@interface UAInAppMessageFullScreenDisplayContentTest : UABaseTest

@end


@implementation UAInAppMessageFullScreenDisplayContentTest

- (void)testTooManyButtons {
    UAInAppMessageFullScreenDisplayContent *fiveButtons =  [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithBuilderBlock:^(UAInAppMessageFullScreenDisplayContentBuilder *builder) {
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

        builder.buttons = @[button, button, button, button, button];
    }];

    XCTAssertTrue(fiveButtons.buttons.count == 5);

    UAInAppMessageFullScreenDisplayContent *sixButtons =  [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithBuilderBlock:^(UAInAppMessageFullScreenDisplayContentBuilder *builder) {
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

        builder.buttons = @[button, button, button, button, button, button];
    }];

    XCTAssertNil(sixButtons);
}

- (void)testNoHeaderOrBody {
    UAInAppMessageFullScreenDisplayContent *headerAndBody =  [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithBuilderBlock:^(UAInAppMessageFullScreenDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];

        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];
    }];

    XCTAssertEqualObjects(headerAndBody.heading.text, @"headline content");
    XCTAssertEqualObjects(headerAndBody.body.text, @"body content");

    UAInAppMessageFullScreenDisplayContent *noHeader =  [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithBuilderBlock:^(UAInAppMessageFullScreenDisplayContentBuilder *builder) {
        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];
    }];

    XCTAssertNil(noHeader.heading);
    XCTAssertEqualObjects(noHeader.body.text, @"body content");

    UAInAppMessageFullScreenDisplayContent *noBody =  [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithBuilderBlock:^(UAInAppMessageFullScreenDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];
    }];

    XCTAssertEqualObjects(noBody.heading.text, @"headline content");
    XCTAssertNil(noBody.body);

    UAInAppMessageFullScreenDisplayContent *noHeaderOrBody =  [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithBuilderBlock:^(UAInAppMessageFullScreenDisplayContentBuilder *builder) {
    }];

    XCTAssertNil(noHeaderOrBody);
}

- (void)testFullScreenDisplayContent {
    UAInAppMessageFullScreenDisplayContent *fromBuilderFullScreenDisplayContent =  [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithBuilderBlock:^(UAInAppMessageFullScreenDisplayContentBuilder *builder) {
        builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;
        builder.contentLayout = UAInAppMessageFullScreenContentLayoutHeaderMediaBody;
        builder.dismissButtonColor = [UIColor greenColor];

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithBuilderBlock:^(UAInAppMessageMediaInfoBuilder * _Nonnull builder) {
            builder.url = @"https://pbs.twimg.com/profile_images/693434931263832064/MQM3kVE-_400x400.jpg";
            builder.type = UAInAppMessageMediaInfoTypeImage;
        }];

        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
            builder.color = [UIColor redColor];
            builder.size = 11;
            builder.alignment = NSTextAlignmentLeft;
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        }];;

        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
            builder.color = [UIColor greenColor];
            builder.size = 11;
            builder.alignment = NSTextAlignmentLeft;
            builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
        }];

        UAInAppMessageButtonInfo *button1 = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Dismiss";
                builder.color = [UIColor blueColor];
                builder.size = 11;
                builder.alignment = NSTextAlignmentLeft;
                builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            }];
            builder.backgroundColor = [UIColor redColor];
        }];

        UAInAppMessageButtonInfo *button2 = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Cancel";
                builder.color = [UIColor redColor];
                builder.size = 9;
                builder.alignment = NSTextAlignmentRight;
                builder.style = UAInAppMessageTextInfoStyleBold | UAInAppMessageTextInfoStyleItalic | UAInAppMessageTextInfoStyleUnderline;
            }];
            builder.backgroundColor = [UIColor blueColor];
            builder.borderRadius = 10;
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        }];

        UAInAppMessageButtonInfo *footerButton = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"footer link";
                builder.color = [UIColor redColor];
                builder.size = 9;
                builder.alignment = NSTextAlignmentCenter;
                builder.style = UAInAppMessageTextInfoStyleUnderline;
            }];
            builder.backgroundColor = [UIColor clearColor];
            builder.borderRadius = 10;
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        }];

        builder.buttons = @[button1, button2];
        builder.footer = footerButton;

    }];

    NSDictionary *JSONFromBuilderFullScreenDisplayContent = [fromBuilderFullScreenDisplayContent toJsonValue];
    NSError *error;
    UAInAppMessageFullScreenDisplayContent *fromJSONFullScreenDisplayContent = [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithJSON:JSONFromBuilderFullScreenDisplayContent error:&error];
    XCTAssertNil(error);

    // Test isEqual and hashing
    XCTAssertEqualObjects(fromBuilderFullScreenDisplayContent, fromJSONFullScreenDisplayContent);
    XCTAssertEqual(fromBuilderFullScreenDisplayContent.hash, fromJSONFullScreenDisplayContent.hash);
}

@end

