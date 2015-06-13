
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "UAirship.h"

@interface UAirshipTest : XCTestCase
@end

@implementation UAirshipTest

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test that if takeOff is called on a background thread that an exception is thrown.
 */
- (void)testExceptionForTakeOffOnNotTheMainThread {

    XCTestExpectation *takeOffCalled = [self expectationWithDescription:@"Takeoff called"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        XCTAssertThrowsSpecificNamed([UAirship takeOff],
                                     NSException, UAirshipTakeOffBackgroundThreadException,
                                     @"Calling takeOff on a background thread should throw a UAirshipTakeOffBackgroundThreadException");
        [takeOffCalled fulfill];
    });


    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
