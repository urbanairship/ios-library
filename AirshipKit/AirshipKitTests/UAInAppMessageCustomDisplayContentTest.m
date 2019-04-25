/* Copyright Airship and Contributors */

#import "UAInAppMessageCustomDisplayContent+Internal.h"
#import "UAInAppMessage.h"
#import "UABaseTest.h"

@interface UAInAppMessageCustomDisplayContentTest : UABaseTest

@end

@implementation UAInAppMessageCustomDisplayContentTest

- (void)testCusotmDisplayContent {
    UAInAppMessageCustomDisplayContent *content = [UAInAppMessageCustomDisplayContent displayContentWithValue:@{@"some-key": @"some-value"}];
    UAInAppMessageCustomDisplayContent *fromJSON = [UAInAppMessageCustomDisplayContent displayContentWithJSON:[content toJSON] error:nil];

    XCTAssertEqualObjects(content, fromJSON);
    XCTAssertEqual(content.hash, fromJSON.hash);
    XCTAssertEqual(content.displayType, fromJSON.displayType);
    XCTAssertEqual(UAInAppMessageDisplayTypeCustom, fromJSON.displayType);
}

@end
