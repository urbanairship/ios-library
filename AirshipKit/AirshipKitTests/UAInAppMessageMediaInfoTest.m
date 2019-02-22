/* Copyright Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageMediaInfo+Internal.h"

@interface UAInAppMessageMediaInfoTest : XCTestCase

@end

@implementation UAInAppMessageMediaInfoTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testMediaInfo {
    UAInAppMessageMediaInfo *mediInfo = [UAInAppMessageMediaInfo mediaInfoWithURL:@"theurl"
                                                               contentDescription:@"some desciription"
                                                                             type:UAInAppMessageMediaInfoTypeYouTube];

    UAInAppMessageMediaInfo *fromJSON = [UAInAppMessageMediaInfo mediaInfoWithJSON:[mediInfo toJSON] error:nil];

    XCTAssertEqualObjects(mediInfo, fromJSON);
    XCTAssertEqual(fromJSON.hash, fromJSON.hash);
}

@end

