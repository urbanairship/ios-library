/* Copyright 2017 Urban Airship and Contributors */

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

/**
 * Creates an automatically managed notification center observer that will execute
 * a block when the notification fires, and automatically remove the observer on teardown.
 *
 * @param block The block to execute when the notification fires.
 * @param notificationName The name of the notification to observer
 * @param sender The sender of the notification
 * @return A disposable that can be used to remove the observer 
 */
- (UADisposable *)startNSNotificationCenterObservingWithBlock:(void (^)(NSNotification *))block notificationName:(NSNotificationName)notificationName sender:(id)sender;

@end
