/* Copyright 2018 Urban Airship and Contributors */

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
    }];

    UAInAppMessageHTMLDisplayContent *newContent = [content extend:^(UAInAppMessageHTMLDisplayContentBuilder * _Nonnull builder) {
        builder.url = @"https://baz.boz.com";
    }];

    XCTAssertNotNil(newContent);
    XCTAssertFalse([newContent isEqual:content]);
    XCTAssertEqualObjects(newContent.backgroundColor, content.backgroundColor);
    XCTAssertEqualObjects(newContent.dismissButtonColor, content.dismissButtonColor);
    XCTAssertEqualObjects(newContent.url, @"https://baz.boz.com");
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (void)testBorderRadius {
    UAInAppMessageHTMLDisplayContent *content =  [UAInAppMessageHTMLDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageHTMLDisplayContentBuilder *builder) {
        builder.url = @"https://foo.bar.com";
        builder.borderRadius = 10;
    }];
    
    XCTAssertNotNil(content);
    XCTAssertEqual(content.borderRadius, 10);
    XCTAssertEqual(content.borderRadiusPoints, 10);

    content =  [UAInAppMessageHTMLDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageHTMLDisplayContentBuilder *builder) {
        builder.url = @"https://foo.bar.com";
        builder.borderRadiusPoints = 10.5;
    }];
    
    XCTAssertNotNil(content);
    XCTAssertEqual(content.borderRadius, 10);
    XCTAssertEqual(content.borderRadiusPoints, 10.5);
}
#pragma GCC diagnostic pop

@end


