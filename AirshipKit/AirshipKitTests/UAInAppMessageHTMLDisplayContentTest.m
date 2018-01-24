/* Copyright 2017 Urban Airship and Contributors */

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
    }];

    UAInAppMessageHTMLDisplayContent *fromJSON = [UAInAppMessageHTMLDisplayContent displayContentWithJSON:[content toJSON] error:nil];

    // Test isEqual and hashing
    XCTAssertEqualObjects(content, fromJSON);
    XCTAssertEqual(content.hash, fromJSON.hash);
}

@end


