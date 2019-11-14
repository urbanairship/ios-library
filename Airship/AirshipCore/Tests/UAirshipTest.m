
#import <UIKit/UIKit.h>
#import "UABaseTest.h"
#import "UAirship.h"
#import "UAConfig.h"

@interface UAirshipTest : UABaseTest
@end

@implementation UAirshipTest


/**
 * Test that if takeOff is called on a background thread that an exception is thrown.
 */
- (void)testExceptionForTakeOffOnNotTheMainThread {
    __block id config = [self mockForClass:[UAConfig class]];
    [[[config stub] andReturn:@YES] validate];

    XCTestExpectation *takeOffCalled = [self expectationWithDescription:@"Takeoff called"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        XCTAssertThrowsSpecificNamed([UAirship takeOff:config],
                                     NSException, UAirshipTakeOffBackgroundThreadException,
                                     @"Calling takeOff on a background thread should throw a UAirshipTakeOffBackgroundThreadException");
        [takeOffCalled fulfill];
    });


    // Wait for the test expectations
    [self waitForTestExpectations];
}

@end
