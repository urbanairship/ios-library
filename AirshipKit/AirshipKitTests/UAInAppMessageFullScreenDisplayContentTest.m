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
            builder.backgroundColor = @"#ff0000"; // red
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
            builder.backgroundColor = @"#ff0000"; // red
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
        builder.buttonLayout = UAInAppMessageButtonLayoutJoined;
        builder.contentLayout = UAInAppMessageFullScreenContentLayoutHeaderMediaBody;
        builder.dismissButtonColor = @"#00ff00"; // green

        builder.media = [UAInAppMessageMediaInfo mediaInfoWithBuilderBlock:^(UAInAppMessageMediaInfoBuilder * _Nonnull builder) {
            builder.url = @"https://pbs.twimg.com/profile_images/693434931263832064/MQM3kVE-_400x400.jpg";
            builder.type = UAInAppMessageMediaInfoTypeImage;
        }];

        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
            builder.color = @"#ff0000"; // red
            builder.size = 11;
            builder.alignment = UAInAppMessageTextInfoAlignmentLeft;
            builder.styles = @[UAInAppMessageTextInfoStyleBold, UAInAppMessageTextInfoStyleItalic, UAInAppMessageTextInfoStyleUnderline];
        }];;

        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
            builder.color = @"#00ff00"; // green
            builder.size = 11;
            builder.alignment = UAInAppMessageTextInfoAlignmentLeft;
            builder.styles = @[UAInAppMessageTextInfoStyleBold, UAInAppMessageTextInfoStyleItalic, UAInAppMessageTextInfoStyleUnderline];
        }];

        UAInAppMessageButtonInfo *button1 = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Dismiss";
                builder.color = @"#0000ff"; // blue
                builder.size = 11;
                builder.alignment = UAInAppMessageTextInfoAlignmentLeft;
                builder.styles = @[UAInAppMessageTextInfoStyleBold, UAInAppMessageTextInfoStyleItalic, UAInAppMessageTextInfoStyleUnderline];
            }];
            builder.backgroundColor = @"#ff0000"; // red
        }];

        UAInAppMessageButtonInfo *button2 = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Cancel";
                builder.color = @"#ff0000"; // red
                builder.size = 9;
                builder.alignment = UAInAppMessageTextInfoAlignmentRight;
                builder.styles = @[UAInAppMessageTextInfoStyleBold, UAInAppMessageTextInfoStyleItalic, UAInAppMessageTextInfoStyleUnderline];
            }];
            builder.backgroundColor = @"#0000ff"; // blue
            builder.borderRadius = 10;
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        }];

        UAInAppMessageButtonInfo *footerButton = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
            builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"footer link";
                builder.color = @"#ff0000"; // red
                builder.size = 9;
                builder.alignment = UAInAppMessageTextInfoAlignmentCenter;
                builder.styles = @[UAInAppMessageTextInfoStyleUnderline];
            }];
            builder.backgroundColor = @"#ff000000"; // clear
            builder.borderRadius = 10;
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        }];

        builder.buttons = @[button1, button2];
        builder.footer = footerButton;

    }];

    NSDictionary *JSONFromBuilderFullScreenDisplayContent = [fromBuilderFullScreenDisplayContent toJsonValue];
    UAInAppMessageFullScreenDisplayContent *fromJSONFullScreenDisplayContent = [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithJSON:JSONFromBuilderFullScreenDisplayContent error:nil];
    NSDictionary *JSONFromJSONFullScreenDisplayContent = [fromJSONFullScreenDisplayContent toJsonValue];

    // Test isEqual and hashing
    XCTAssertTrue([fromBuilderFullScreenDisplayContent isEqual:fromJSONFullScreenDisplayContent] == YES);
    XCTAssertEqual(fromBuilderFullScreenDisplayContent.hash, fromJSONFullScreenDisplayContent.hash);

    // Test conversion to JSON
    XCTAssertEqualObjects(JSONFromBuilderFullScreenDisplayContent, JSONFromJSONFullScreenDisplayContent);
}

@end

