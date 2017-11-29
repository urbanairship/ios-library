/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAInAppMessageMediaInfo.h"

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
    UAInAppMessageMediaInfo *fromBuilderMediaInfo = [UAInAppMessageMediaInfo mediaInfoWithBuilderBlock:^(UAInAppMessageMediaInfoBuilder * _Nonnull builder) {
        builder.url = @"theurl";
        builder.type = UAInAppMessageMediaInfoTypeYouTube;
    }];

    NSDictionary *JSONFromBuilderMediaInfo = [UAInAppMessageMediaInfo JSONWithMediaInfo:fromBuilderMediaInfo];
    UAInAppMessageMediaInfo *fromJSONMediaInfo = [UAInAppMessageMediaInfo mediaInfoWithJSON:JSONFromBuilderMediaInfo error:nil];
    NSDictionary *JSONFromJSONMediaInfo = [UAInAppMessageMediaInfo JSONWithMediaInfo:fromJSONMediaInfo];

    // Test isEqual and hashing
    XCTAssertTrue([fromBuilderMediaInfo isEqual:fromJSONMediaInfo] == YES);
    XCTAssertEqual(fromBuilderMediaInfo.hash, fromJSONMediaInfo.hash);

    // Test conversion to JSON
    XCTAssertEqualObjects(JSONFromBuilderMediaInfo, JSONFromJSONMediaInfo);
    XCTAssertTrue([JSONFromBuilderMediaInfo isEqual:JSONFromJSONMediaInfo] == YES);
}

@end

