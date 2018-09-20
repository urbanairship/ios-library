/* Copyright 2018 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UADisposable.h"
#import "UAPreferenceDataStore+Internal.h"

extern const NSTimeInterval UATestExpectationTimeOut;

@interface UABaseTest : XCTestCase

/**
 * A preference data store unique to this test. The dataStore is created
 * lazily when first used.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

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
 * Waits for all test expectations with the default timeout.
 */
- (void)waitForTestExpectations;

@end
