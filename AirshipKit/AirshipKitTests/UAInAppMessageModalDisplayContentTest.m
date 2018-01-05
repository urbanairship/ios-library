/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageModalDisplayContent+Internal.h"
#import "UABaseTest.h"

@interface UAInAppMessageModalDisplayContentTest : UABaseTest

@end


@implementation UAInAppMessageModalDisplayContentTest

- (void)testTooManyButtons {
    UAInAppMessageModalDisplayContent *twoButtons =  [UAInAppMessageModalDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageModalDisplayContentBuilder *builder) {
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
    
    UAInAppMessageModalDisplayContent *threeButtons =  [UAInAppMessageModalDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageModalDisplayContentBuilder *builder) {
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
        
        builder.buttons = @[button, button, button];
    }];
    
    XCTAssertNil(threeButtons);
}

- (void)testNoHeaderOrBody {
    UAInAppMessageModalDisplayContent *headerAndBody =  [UAInAppMessageModalDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageModalDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];
        
        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];
    }];
    
    XCTAssertEqualObjects(headerAndBody.heading.text, @"headline content");
    XCTAssertEqualObjects(headerAndBody.body.text, @"body content");
    
    UAInAppMessageModalDisplayContent *noHeader =  [UAInAppMessageModalDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageModalDisplayContentBuilder *builder) {
        builder.body = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"body content";
        }];
    }];
    
    XCTAssertNil(noHeader.heading);
    XCTAssertEqualObjects(noHeader.body.text, @"body content");
    
    UAInAppMessageModalDisplayContent *noBody =  [UAInAppMessageModalDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageModalDisplayContentBuilder *builder) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = @"headline content";
        }];
    }];
    
    XCTAssertEqualObjects(noBody.heading.text, @"headline content");
    XCTAssertNil(noBody.body);
    
    UAInAppMessageModalDisplayContent *noHeaderOrBody =  [UAInAppMessageModalDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageModalDisplayContentBuilder *builder) {
    }];
    
    XCTAssertNil(noHeaderOrBody);
}

- (void)testModalDisplayContent {
    UAInAppMessageModalDisplayContent *content =  [UAInAppMessageModalDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageModalDisplayContentBuilder *builder) {
        builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;
        builder.contentLayout = UAInAppMessageModalContentLayoutHeaderMediaBody;
        builder.dismissButtonColor = [UIColor greenColor];
        
        builder.media = [UAInAppMessageMediaInfo mediaInfoWithURL:@"some url"
                                               contentDescription:@"some-description" type:UAInAppMessageMediaInfoTypeImage];
        
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
            builder.identifier = @"button";
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
            builder.identifier = @"button";
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
            builder.identifier = @"button";
        }];
        
        builder.buttons = @[button1, button2];
        builder.footer = footerButton;
        
    }];
    
    UAInAppMessageModalDisplayContent *fromJSON = [UAInAppMessageModalDisplayContent displayContentWithJSON:[content toJSON] error:nil];
    
    // Test isEqual and hashing
    XCTAssertEqualObjects(content, fromJSON);
    XCTAssertEqual(content.hash, fromJSON.hash);
}

@end
