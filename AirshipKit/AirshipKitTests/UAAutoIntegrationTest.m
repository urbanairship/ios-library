/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <objc/runtime.h>
#import <UserNotifications/UserNotifications.h>
#import "UAAutoIntegration+Internal.h"
#import "UAAppIntegration.h"

@interface UAAutoIntegrationTest : XCTestCase
@property (nonatomic, strong) id mockAppIntegration;
@property (nonatomic, strong) id delegate;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockUserNotificationCenter;
@property (nonatomic, strong) id mockProcessInfo;
@property (nonatomic, assign) int testOSMajorVersion;

@property (nonatomic, assign) Class generatedClass;
@end

@implementation UAAutoIntegrationTest

- (void)setUp {
    [super setUp];

    // Set default OS major version to 10 by default
    self.testOSMajorVersion = 10;
    self.mockProcessInfo = [OCMockObject niceMockForClass:[NSProcessInfo class]];
    [[[self.mockProcessInfo stub] andReturn:self.mockProcessInfo] processInfo];

    [[[[self.mockProcessInfo stub] andDo:^(NSInvocation *invocation) {
        NSOperatingSystemVersion arg;
        [invocation getArgument:&arg atIndex:2];

        BOOL result = self.testOSMajorVersion >= arg.majorVersion;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){0, 0, 0}];


    self.mockAppIntegration = [OCMockObject niceMockForClass:[UAAppIntegration class]];

    // Generate a new class for each test run to avoid test pollution
    self.generatedClass = objc_allocateClassPair([NSObject class], [[NSUUID UUID].UUIDString UTF8String], 0);
    objc_registerClassPair(self.generatedClass);

    self.delegate = [[self.generatedClass alloc] init];

    self.mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
    [[[self.mockApplication stub] andReturn:self.delegate] delegate];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    self.mockUserNotificationCenter = [OCMockObject niceMockForClass:[UNUserNotificationCenter class]];
    [[[self.mockUserNotificationCenter stub] andReturn:self.mockUserNotificationCenter] currentNotificationCenter];
}

- (void)tearDown {
    [self.mockAppIntegration stopMocking];
    [self.mockApplication stopMocking];
    [self.mockUserNotificationCenter stopMocking];
    [self.mockProcessInfo stopMocking];

    [UAAutoIntegration reset];

    self.delegate = nil;

    if (self.generatedClass) {
        objc_disposeClassPair(self.generatedClass);
    }

    [super tearDown];
}

#pragma AppDelegate callbacks

/**
 * Test integrating application:didFailToRegisterForRemoteNotificationsWithError:
 * calls the original.
 */
- (void)testProxyFailedToRegisterWithError {
    __block BOOL appDelegateCalled;

    NSError *expectedError = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

    // Add an implementation for application:didFailToRegisterForRemoteNotificationsWithError:
    [self addImplementationForProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)
                                 block:^(id self, UIApplication *application, NSError *error) {
                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedError, error);
                                 }];

    [UAAutoIntegration integrate];

    [self.delegate application:[UIApplication sharedApplication] didFailToRegisterForRemoteNotificationsWithError:expectedError];

    // Verify everything was called
    XCTAssertTrue(appDelegateCalled);
}

/**
 * Test UNUserNotificationCenter's setDelegate is called to set the delegate to the dummy delegate by default.
 */
- (void)testProxyUserNotificationCenterSetDummyDelegate {
    self.testOSMajorVersion = 10;

    // Expect the setDelegate call
    [[self.mockUserNotificationCenter expect] setDelegate:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAAutoIntegrationDummyDelegate class]];
    }]];

    // Proxy the delegate
    [UAAutoIntegration integrate];

    [self.mockUserNotificationCenter verify];
}

/**
 * Test proxying application:didRegisterForRemoteNotificationsWithDeviceToken: when the delegate implementts
 * the selector calls the original and UAAppHooks.
 */
- (void)testProxyAppRegisteredForRemoteNotificationsWithDeviceToken {
    __block BOOL appDelegateCalled;

    NSData *expectedDeviceToken = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];

    // Add an implementation for application:didRegisterForRemoteNotificationsWithDeviceToken:
    [self addImplementationForProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
                                 block:^(id self, UIApplication *application, NSData *deviceToken) {
                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedDeviceToken, deviceToken);
                                 }];

    // Expect the UAAppHook call
    [[self.mockAppIntegration expect] application:self.mockApplication didRegisterForRemoteNotificationsWithDeviceToken:expectedDeviceToken];

    // Proxy the delegate
    [UAAutoIntegration integrate];

    // Call application:didRegisterForRemoteNotificationsWithDeviceToken:
    [self.delegate application:[UIApplication sharedApplication] didRegisterForRemoteNotificationsWithDeviceToken:expectedDeviceToken];

    // Verify everything was called
    XCTAssertTrue(appDelegateCalled);
    [self.mockAppIntegration verify];
}

/**
 * Test adding application:didRegisterForRemoteNotificationsWithDeviceToken: calls UAAppHooks.
 */
- (void)testAddAppRegisteredForRemoteNotificationsWithDeviceToken {
    NSData *expectedDeviceToken = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];

    // Expect the UAAppHook call
    [[self.mockAppIntegration expect] application:self.mockApplication   didRegisterForRemoteNotificationsWithDeviceToken:expectedDeviceToken];

    // Proxy the delegate
    [UAAutoIntegration integrate];

    // Call application:didRegisterForRemoteNotificationsWithDeviceToken:
    [self.delegate application:[UIApplication sharedApplication] didRegisterForRemoteNotificationsWithDeviceToken:expectedDeviceToken];

    // Verify everything was called
    [self.mockAppIntegration verify];
}

/*
 * Tests proxying application:didReceiveRemoteNotification:fetchCompletionHandler
 * responds with the combined value of the app delegate and UAAppHooks.
 */
- (void)testProxAppReceivedRemoteNotificationWithCompletionHandler {
    NSDictionary *expectedNotification = @{@"oh": @"hi"};

    // Add an implementation for application:didReceiveRemoteNotification:fetchCompletionHandler: that
    // calls an expected fetch result
    __block UIBackgroundFetchResult appDelegateResult;
    __block BOOL appDelegateCalled;
    [self addImplementationForProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
                                 block:^(id self, UIApplication *application, NSDictionary *notification, void (^completion)(UIBackgroundFetchResult) ) {

                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedNotification, notification);
                                     XCTAssertNotNil(completion);
                                     completion(appDelegateResult);
                                 }];

    // Add an implementation for UAPush that calls an expected fetch result
    __block UIBackgroundFetchResult pushResult;
    __block BOOL pushCalled;

    void (^pushBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        pushCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;
        handler(pushResult);
    };

    [[[self.mockAppIntegration stub] andDo:pushBlock] application:self.mockApplication
                               didReceiveRemoteNotification:expectedNotification
                                     fetchCompletionHandler:OCMOCK_ANY];


    // Proxy the delegate
    [UAAutoIntegration integrate];


    // Iterate through the results to verify we combine them properly

    UIBackgroundFetchResult allBackgroundFetchResults[] = { UIBackgroundFetchResultNoData,
        UIBackgroundFetchResultFailed, UIBackgroundFetchResultNewData };

    // The expected matrix from the different combined values of allBackgroundFetchResults indicies
    UIBackgroundFetchResult expectedResults[3][3] = {
        {UIBackgroundFetchResultNoData, UIBackgroundFetchResultFailed, UIBackgroundFetchResultNewData},
        {UIBackgroundFetchResultFailed, UIBackgroundFetchResultFailed, UIBackgroundFetchResultNewData},
        {UIBackgroundFetchResultNewData, UIBackgroundFetchResultNewData, UIBackgroundFetchResultNewData}
    };

    for (int i = 0; i < 3; i++) {
        // Set the push result
        pushResult = allBackgroundFetchResults[i];

        for (int j = 0; j < 3; j++) {

            appDelegateCalled = NO;
            pushCalled = NO;

            XCTestExpectation *callBackFinished = [self expectationWithDescription:@"Callback called"];
            UIBackgroundFetchResult expectedResult = expectedResults[i][j];

            // Set the app delegate result
            appDelegateResult = allBackgroundFetchResults[j];

            // Verify that the expected value is returned from combining the two results
            [self.delegate application:[UIApplication sharedApplication]
          didReceiveRemoteNotification:expectedNotification
                fetchCompletionHandler:^(UIBackgroundFetchResult result){
                    XCTAssertEqual(expectedResult, result);
                    [callBackFinished fulfill];
                }];

            // Wait for the test expectations
            [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
                XCTAssertTrue(pushCalled);
                XCTAssertTrue(appDelegateCalled);
            }];
        }
    }
}

/*
 * Tests adding application:didReceiveRemoteNotification:fetchCompletionHandler calls
 * through to UAAppHooks.
 */
- (void)testAddAppReceivedRemoteNotificationWithCompletionHandler {
    NSDictionary *expectedNotification = @{@"oh": @"hi"};

    __block BOOL pushCalled;

    // Add an implementation for UAPush that calls an expected fetch result
    void (^pushBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        pushCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;
        handler(UIBackgroundFetchResultNewData);
    };

    [[[self.mockAppIntegration stub] andDo:pushBlock] application:self.mockApplication
                               didReceiveRemoteNotification:expectedNotification
                                     fetchCompletionHandler:OCMOCK_ANY];


    // Proxy the delegate
    [UAAutoIntegration integrate];

    // Verify that the expected value is returned from combining the two results
    [self.delegate application:[UIApplication sharedApplication]
  didReceiveRemoteNotification:expectedNotification
        fetchCompletionHandler:^(UIBackgroundFetchResult result){
            XCTAssertEqual(UIBackgroundFetchResultNewData, result);
        }];
    
    XCTAssertTrue(pushCalled);
}

/**
 * iOS 8/9 only - Test proxying application:didRegisterForRemoteNotificationsWithDeviceToken: when the delegate implements
 * the selector calls the original and UAPush.
 */
- (void)testProxyAppRegisteredUserNotificationSettings {
    self.testOSMajorVersion = 8;
    __block BOOL appDelegateCalled;

    UIUserNotificationSettings *expectedSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];

    // Add an implementation for application:didRegisterUserNotificationSettings:
    [self addImplementationForProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:didRegisterUserNotificationSettings:)
                                 block:^(id self, UIApplication *application, UIUserNotificationSettings *settings) {
                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedSettings, settings);
                                 }];

    // Expect the UAAppIntegration call
    [[self.mockAppIntegration expect] application:self.mockApplication didRegisterUserNotificationSettings:expectedSettings];

    // Proxy the delegate
    [UAAutoIntegration integrate];

    // Call application:didRegisterUserNotificationSettings:
    [self.delegate application:[UIApplication sharedApplication] didRegisterUserNotificationSettings:expectedSettings];

    // Verify everything was called
    XCTAssertTrue(appDelegateCalled);
    [self.mockApplication verify];
}

/**
 * iOS 8/9 only - Test adding application:didRegisterUserNotificationSettings: calls UAPush.
 */
- (void)testAddAppRegisteredUserNotificationSettings {
    self.testOSMajorVersion = 8;
    UIUserNotificationSettings *expectedSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];

    // Expect the UAPush integration
    [[self.mockAppIntegration expect] application:self.mockApplication didRegisterUserNotificationSettings:expectedSettings];

    // Proxy the delegate
    [UAAutoIntegration integrate];

    // Call application:didRegisterUserNotificationSettings:
    [self.delegate application:[UIApplication sharedApplication] didRegisterUserNotificationSettings:expectedSettings];

    // Verify everything was called
    [self.mockAppIntegration verify];
}

/*
 * iOS 8/9 only - Tests adding application:handleActionWithIdentifier:forRemoteNotification:completionHandler: calls
 * through to UAPush
 */
- (void)testAddAppReceivedActionWithIdentifier {
    self.testOSMajorVersion = 8;
    NSDictionary *expectedNotification = @{@"oh": @"hi"};

    // Add an implementation for UAAppIntegration that calls an expected fetch result
    __block BOOL appIntegrationCalled;
    void (^appIntegrationBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        appIntegrationCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^handler)() = (__bridge void (^)())arg;
        handler();
    };

    [[[self.mockAppIntegration stub] andDo:appIntegrationBlock] application:self.mockApplication
                                                 handleActionWithIdentifier:@"action!"
                                                      forRemoteNotification:expectedNotification
                                                          completionHandler:OCMOCK_ANY];

    // Proxy the delegate
    [UAAutoIntegration integrate];

    // Verify that the expected value is returned from combining the two results
    __block BOOL completionHandlerCalled;
    [self.delegate application:[UIApplication sharedApplication]
    handleActionWithIdentifier:@"action!"
         forRemoteNotification:expectedNotification
             completionHandler:^(){
                 completionHandlerCalled = YES;
             }];

    XCTAssertTrue(appIntegrationCalled);
    XCTAssertTrue(completionHandlerCalled);
}

/*
 * iOS 8/9 only - Tests adding application:handleActionWithIdentifier:forRemoteNotification:completionHandler: calls
 * through to UAPush and the original delegate.
 */
- (void)testProxyAppReceivedActionWithIdentifier {
    self.testOSMajorVersion = 8;

    XCTestExpectation *callBackFinished = [self expectationWithDescription:@"App delegate callback called"];

    NSDictionary *expectedNotification = @{@"oh": @"hi"};

    // Add implementation to the app delegate
    __block BOOL appDelegateCalled;
    [self addImplementationForProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:handleActionWithIdentifier:forRemoteNotification:completionHandler:)
                                 block:^(id self, UIApplication *application, NSString *identifier, NSDictionary *notification, void (^completion)() ) {

                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedNotification, notification);
                                     XCTAssertEqualObjects(@"action!", identifier);

                                     XCTAssertNotNil(completion);
                                     completion();
                                 }];


    // Stub the implementation for UAPush that calls an expected fetch result
    __block BOOL appIntegrationCalled;
    void (^appIntegrationBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        appIntegrationCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^handler)() = (__bridge void (^)())arg;
        handler();
    };

    [[[self.mockAppIntegration stub] andDo:appIntegrationBlock] application:self.mockApplication
                                                 handleActionWithIdentifier:@"action!"
                                                      forRemoteNotification:expectedNotification
                                                          completionHandler:OCMOCK_ANY];

    // Proxy the delegate
    [UAAutoIntegration integrate];

    // Verify that the expected value is returned from combining the two results
    __block BOOL completionHandlerCalled;
    [self.delegate application:[UIApplication sharedApplication]
    handleActionWithIdentifier:@"action!"
         forRemoteNotification:expectedNotification
             completionHandler:^(){
                 [callBackFinished fulfill];
                 completionHandlerCalled = YES;
             }];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        XCTAssertTrue(appIntegrationCalled);
        XCTAssertTrue(completionHandlerCalled);
        XCTAssertTrue(appDelegateCalled);
    }];

}

/*
 * iOS 8/9 only - Tests adding application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler: calls
 * through to UAPush and the original delegate.
 */
- (void)testProxyAppReceivedActionWithIdentifierWithResponseInfo {
    self.testOSMajorVersion = 8;

    XCTestExpectation *callBackFinished = [self expectationWithDescription:@"App delegate callback called"];

    NSDictionary *expectedNotification = @{@"oh": @"hi"};
    NSDictionary *expectedResponseInfo = @{@"UIUserNotificationActionResponseTypedTextKey": @"shucks howdy"};

    // Add implementation to the app delegate
    __block BOOL appDelegateCalled;
    [self addImplementationForProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)
                                 block:^(id self, UIApplication *application, NSString *identifier, NSDictionary *notification, NSDictionary *responseInfo, void (^completion)() ) {

                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedNotification, notification);
                                     XCTAssertEqualObjects(expectedResponseInfo, responseInfo);
                                     XCTAssertEqualObjects(@"action!", identifier);

                                     XCTAssertNotNil(completion);
                                     completion();
                                 }];


    // Stub the implementation for UAPush that calls an expected fetch result
    __block BOOL appIntegrationCalled;
    void (^appIntegrationBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        appIntegrationCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:6];
        void (^handler)() = (__bridge void (^)())arg;
        handler();
    };

    [[[self.mockAppIntegration stub] andDo:appIntegrationBlock] application:self.mockApplication
                                                 handleActionWithIdentifier:@"action!"
                                                      forRemoteNotification:expectedNotification
                                                           withResponseInfo:expectedResponseInfo
                                                          completionHandler:OCMOCK_ANY];

    // Proxy the delegate
    [UAAutoIntegration integrate];

    __block BOOL completionHandlerCalled;

    // Verify that the expected value is returned from combining the two results
    [self.delegate application:[UIApplication sharedApplication]
    handleActionWithIdentifier:@"action!"
         forRemoteNotification:expectedNotification
              withResponseInfo:expectedResponseInfo
             completionHandler:^(){
                 [callBackFinished fulfill];
                 completionHandlerCalled = YES;
             }];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        XCTAssertTrue(appIntegrationCalled);
        XCTAssertTrue(completionHandlerCalled);
        XCTAssertTrue(appDelegateCalled);
    }];
}

#pragma UNUserNotificationCenterDelegate callbacks


#pragma Helpers

/**
 * Adds a block based implementation to the app delegate with the given selector.
 *
 * @param protocol The protocol to which the implementation will be added.
 * @param selector A selector for the given protocol
 * @param block A block that matches the encoding of the selector. The first argument
 * must be self.
 */
- (void)addImplementationForProtocol:(id)protocol selector:(SEL)selector block:(id)block {
    struct objc_method_description description = protocol_getMethodDescription(protocol, selector, NO, YES);
    IMP implementation = imp_implementationWithBlock(block);
    class_addMethod(self.generatedClass, selector, implementation, description.types);
}

@end
