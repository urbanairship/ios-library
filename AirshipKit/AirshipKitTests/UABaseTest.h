/* Copyright 2018 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UADisposable.h"

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
 * Creates a partial mock.
 * @param object The object to mock.
 * @return The partial mock instance.
 */
- (id)partialMockForObject:(NSObject *)object;

@end
