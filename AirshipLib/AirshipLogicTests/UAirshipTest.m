
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        XCTAssertFalse([[NSThread currentThread] isMainThread], @"Test invalid, running on the main thread");
        XCTAssertThrowsSpecificNamed(
            [UAirship takeOff],
            NSException, UAirshipTakeOffBackgroundThreadException,
            @"Calling takeOff on a background thread should throw a UAirshipTakeOffBackgroundThreadException");
    });
}

@end
