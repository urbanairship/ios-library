/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAInAppMessage.h"
#import "UABaseTest.h"

@interface UAInAppMessageHTMLDisplayContentTest : UABaseTest
@end

@implementation UAInAppMessageHTMLDisplayContentTest

- (void)testHTMLDisplayContent {
    UAInAppMessageHTMLDisplayContent *content =  [UAInAppMessageHTMLDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageHTMLDisplayContentBuilder *builder) {
        builder.backgroundColor = [UIColor blueColor];
        builder.dismissButtonColor = [UIColor greenColor];
        builder.url = @"https://foo.bar.com";
        builder.borderRadiusPoints = 10;
        builder.requiresConnectivity = YES;
        builder.width = 99;
        builder.height = 99;
        builder.aspectLock = YES;
    }];

    UAInAppMessageHTMLDisplayContent *fromJSON = [UAInAppMessageHTMLDisplayContent displayContentWithJSON:[content toJSON] error:nil];

    // Test isEqual and hashing
    XCTAssertEqualObjects(content, fromJSON);
    XCTAssertEqual(content.hash, fromJSON.hash);
}

- (void)testExtend {
    UAInAppMessageHTMLDisplayContent *content =  [UAInAppMessageHTMLDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageHTMLDisplayContentBuilder *builder) {
        builder.backgroundColor = [UIColor blueColor];
        builder.dismissButtonColor = [UIColor greenColor];
        builder.url = @"https://foo.bar.com";
        builder.borderRadiusPoints = 10.5;
        builder.requiresConnectivity = YES;
        builder.width = 99;
        builder.height = 99;
        builder.aspectLock = YES;
    }];

    UAInAppMessageHTMLDisplayContent *newContent = [content extend:^(UAInAppMessageHTMLDisplayContentBuilder * _Nonnull builder) {
        builder.url = @"https://baz.boz.com";
        builder.requiresConnectivity = YES;
        builder.aspectLock = NO;
    }];

    XCTAssertNotNil(newContent);
    XCTAssertFalse([newContent isEqual:content]);
    XCTAssertEqualObjects(newContent.backgroundColor, content.backgroundColor);
    XCTAssertEqualObjects(newContent.dismissButtonColor, content.dismissButtonColor);
    XCTAssertEqualObjects(newContent.url, @"https://baz.boz.com");

    XCTAssertEqual(newContent.width, content.width);
    XCTAssertEqual(newContent.height, content.height);
    XCTAssertNotEqual(newContent.aspectLock, content.aspectLock);

    XCTAssertEqualObjects(newContent.dismissButtonColor, content.dismissButtonColor);
    XCTAssertEqualObjects(newContent.url, @"https://baz.boz.com");
}

@end


