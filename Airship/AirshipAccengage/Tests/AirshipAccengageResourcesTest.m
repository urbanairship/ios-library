/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>

#import "UAAccengageResources.h"

@interface AirshipAccengageResourcesTests : XCTestCase

@end

@implementation AirshipAccengageResourcesTests

- (void)testBundle {
    NSBundle *bundle = [UAAccengageResources bundle];
    XCTAssertNotNil(bundle, @"Bundle should not be nil");
}

@end
