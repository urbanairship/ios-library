/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

extern NSTimeInterval const UATestExpectationTimeOut;

@interface UABaseTest : XCTestCase

/**
 * Creates a nice mock for a given class.
 * @param aClass The class to mock.
 * @return The mocked class instance.
 */
- (id)mockForClass:(Class)aClass;

/**
 * Creates a strict mock for a given class.
 * @param aClass The class to mock.
 * @return The mocked class instance.
 */
- (id)strictMockForClass:(Class)aClass;

/**
 * Creates a nice mock for a given protocol.
 * @param protocol The protocol to mock.
 * @return The mocked class instance.
 */
- (id)mockForProtocol:(Protocol *)protocol;

/**
 * Creates a strict mock for a given protocol.
 * @param protocol The protocol to mock.
 * @return The mocked class instance.
*/
- (id)strictMockForProtocol:(Protocol *)protocol;

/**
 * Creates a partial mock.
 * @param object The object to mock.
 * @return The partial mock instance.
 */
- (id)partialMockForObject:(NSObject *)object;

/**
 * Waits for test expectations with the default timeout.
 * @param expectations The test expectations.
 */
- (void)waitForTestExpectations:(NSArray<XCTestExpectation *> *)expectations;

/**
 * Waits for test expectations with the default timeout.
 * @param expectations The test expectations.
 * @param enforceOrder Whether to enforce expectation order.
*/
- (void)waitForTestExpectations:(NSArray<XCTestExpectation *> *)expectations enforceOrder:(BOOL)enforceOrder;

/**
 * Waits for all test expectations with the default timeout.
 */
- (void)waitForTestExpectations;


@end
