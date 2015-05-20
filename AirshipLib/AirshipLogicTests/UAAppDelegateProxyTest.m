/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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
#import "UAAppDelegateProxy+Internal.h"
#import "UAirship.h"
#import "UAPush.h"

@interface UAAppDelegateProxyTest : XCTestCase
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id delegate;
@property (nonatomic, strong) id mockApplication;

@property (nonatomic, assign) Class generatedClass;
@end

@implementation UAAppDelegateProxyTest

- (void)setUp {
    [super setUp];

    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];
    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];

    // Generate a new class for each test run to avoid test pollution
    self.generatedClass = objc_allocateClassPair([NSObject class], [[NSUUID UUID].UUIDString UTF8String], 0);
    objc_registerClassPair(self.generatedClass);

    self.delegate = [[self.generatedClass alloc] init];

    self.mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
    [[[self.mockApplication stub] andReturn:self.delegate] delegate];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockPush stopMocking];
    [self.mockApplication stopMocking];

    self.delegate = nil;

    if (self.generatedClass) {
        objc_disposeClassPair(self.generatedClass);
    }

    [super tearDown];
}

/**
 * Test proxying application:didFailToRegisterForRemoteNotificationsWithError:
 * calls the original.
 */
- (void)testProxyFailedToRegisterWithError {
    __block BOOL appDelegateCalled;

    NSError *expectedError = [NSError errorWithDomain:@"test" code:1 userInfo:nil];

    // Add an implementation for application:didFailToRegisterForRemoteNotificationsWithError:
    [self addAppDelegateImplementation:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)
                                 block:^(id self, UIApplication *application, NSError *error) {
                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedError, error);
                                 }];

    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

    // Call application:didFailToRegisterForRemoteNotificationsWithError:
    [self.delegate application:[UIApplication sharedApplication] didFailToRegisterForRemoteNotificationsWithError:expectedError];

    // Verify everything was called
    XCTAssertTrue(appDelegateCalled);
}

/**
 * Test proxying application:didReceiveRemoteNotification: when the delegate implments
 * the selector calls the original and UAPush.
 */
- (void)testProxyAppReceivedRemoteNotification {
    __block BOOL appDelegateCalled;

    NSDictionary *expectedNotification = @{@"oh": @"hi"};

    // Add an implementation for application:didReceiveRemoteNotification:
    [self addAppDelegateImplementation:@selector(application:didReceiveRemoteNotification:)
                                 block:^(id self, UIApplication *application, NSDictionary *notification) {
                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedNotification, notification);
                                 }];

    // Expect the UAPush integration
    [[self.mockPush expect] appReceivedRemoteNotification:expectedNotification
                                         applicationState:[UIApplication sharedApplication].applicationState];

    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

    // Call application:didFailToRegisterForRemoteNotificationsWithError:
    [self.delegate application:[UIApplication sharedApplication] didReceiveRemoteNotification:expectedNotification];

    // Verify everything was called
    XCTAssertTrue(appDelegateCalled);
    [self.mockPush verify];
}

/**
 * Test adding application:didReceiveRemoteNotification: calls UAPush.
 */
- (void)testAddAppReceivedRemoteNotification {
    NSDictionary *expectedNotification = @{@"oh": @"hi"};

    // Expect the UAPush integration
    [[self.mockPush expect] appReceivedRemoteNotification:expectedNotification applicationState:[UIApplication sharedApplication].applicationState];

    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

    // Call application:didFailToRegisterForRemoteNotificationsWithError:
    [self.delegate application:[UIApplication sharedApplication] didReceiveRemoteNotification:expectedNotification];

    // Verify everything was called
    [self.mockPush verify];
}


/**
 * Test proxying application:didRegisterForRemoteNotificationsWithDeviceToken: when the delegate implments
 * the selector calls the original and UAPush.
 */
- (void)testProxyAppRegisteredForRemoteNotificationsWithDeviceToken {
    __block BOOL appDelegateCalled;

    NSData *expectedDeviceToken = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];

    // Add an implementation for application:didReceiveRemoteNotification:
    [self addAppDelegateImplementation:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
                                 block:^(id self, UIApplication *application, NSData *deviceToken) {
                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedDeviceToken, deviceToken);
                                 }];

    // Expect the UAPush integration
    [[self.mockPush expect] appRegisteredForRemoteNotificationsWithDeviceToken:expectedDeviceToken];

    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

    // Call application:didFailToRegisterForRemoteNotificationsWithError:
    [self.delegate application:[UIApplication sharedApplication] didRegisterForRemoteNotificationsWithDeviceToken:expectedDeviceToken];

    // Verify everything was called
    XCTAssertTrue(appDelegateCalled);
    [self.mockPush verify];
}

/**
 * Test adding application:didRegisterForRemoteNotificationsWithDeviceToken: calls UAPush.
 */
- (void)testAddAppRegisteredForRemoteNotificationsWithDeviceToken {
    NSData *expectedDeviceToken = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];

    // Expect the UAPush integration
    [[self.mockPush expect] appRegisteredForRemoteNotificationsWithDeviceToken:expectedDeviceToken];

    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

    // Call application:didFailToRegisterForRemoteNotificationsWithError:
    [self.delegate application:[UIApplication sharedApplication] didRegisterForRemoteNotificationsWithDeviceToken:expectedDeviceToken];

    // Verify everything was called
    [self.mockPush verify];
}


/**
 * Test proxying application:didRegisterForRemoteNotificationsWithDeviceToken: when the delegate implments
 * the selector calls the original and UAPush.
 */
- (void)testProxyAppRegisteredUserNotificationSettings {
    __block BOOL appDelegateCalled;

    UIUserNotificationSettings *expectedSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];

    // Add an implementation for application:didReceiveRemoteNotification:
    [self addAppDelegateImplementation:@selector(application:didRegisterUserNotificationSettings:)
                                 block:^(id self, UIApplication *application, UIUserNotificationSettings *settings) {
                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertEqualObjects(expectedSettings, settings);
                                 }];

    // Expect the UAPush integration
    [[self.mockPush expect] appRegisteredUserNotificationSettings];

    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

    // Call application:didFailToRegisterForRemoteNotificationsWithError:
    [self.delegate application:[UIApplication sharedApplication] didRegisterUserNotificationSettings:expectedSettings];

    // Verify everything was called
    XCTAssertTrue(appDelegateCalled);
    [self.mockPush verify];
}

/**
 * Test adding application:didRegisterUserNotificationSettings: calls UAPush.
 */
- (void)testAddAppRegisteredUserNotificationSettings {
    UIUserNotificationSettings *expectedSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];

    // Expect the UAPush integration
    [[self.mockPush expect] appRegisteredUserNotificationSettings];

    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

    // Call application:didFailToRegisterForRemoteNotificationsWithError:
    [self.delegate application:[UIApplication sharedApplication] didRegisterUserNotificationSettings:expectedSettings];

    // Verify everything was called
    [self.mockPush verify];
}


/*
 * Tests proxying application:didReceiveRemoteNotification:fetchCompletionHandler
 * responds with the combined value of the app delegate and UAPush.
 */
- (void)testProxAppReceivedRemoteNotificationWithCompletionHandler {

    NSDictionary *expectedNotification = @{@"oh": @"hi"};

    // Add an implementation for application:didReceiveRemoteNotification:fetchCompletionHandler: that
    // calls an expecrted fetch result
    __block UIBackgroundFetchResult appDelegateResult;
    __block BOOL appDelegateCalled;
    [self addAppDelegateImplementation:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
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

    [[[self.mockPush stub] andDo:pushBlock] appReceivedRemoteNotification:expectedNotification
                                                         applicationState:UIApplicationStateActive
                                                   fetchCompletionHandler:OCMOCK_ANY];


    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];


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
 * through to UAPush
 */
- (void)testAddAppReceivedRemoteNotificationWithCompletionHandler {

    NSDictionary *expectedNotification = @{@"oh": @"hi"};


    // Add an implementation for UAPush that calls an expected fetch result
    __block BOOL pushCalled;

    void (^pushBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        pushCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;
        handler(UIBackgroundFetchResultNewData);
    };

    [[[self.mockPush stub] andDo:pushBlock] appReceivedRemoteNotification:expectedNotification
                                                         applicationState:UIApplicationStateActive
                                                   fetchCompletionHandler:OCMOCK_ANY];


    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

    // Verify that the expected value is returned from combining the two results
    [self.delegate application:[UIApplication sharedApplication]
  didReceiveRemoteNotification:expectedNotification
        fetchCompletionHandler:^(UIBackgroundFetchResult result){
            XCTAssertEqual(UIBackgroundFetchResultNewData, result);
        }];

     XCTAssertTrue(pushCalled);
}


/*
 * Tests adding application:handleActionWithIdentifier:forRemoteNotification:completionHandler: calls
 * through to UAPush
 */
- (void)testAddAppReceivedActionWithIdentifier {

    NSDictionary *expectedNotification = @{@"oh": @"hi"};


    // Add an implementation for UAPush that calls an expected fetch result
    __block BOOL pushCalled;
    void (^pushBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        pushCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^handler)() = (__bridge void (^)())arg;
        handler();
    };

    [[[self.mockPush stub] andDo:pushBlock] appReceivedActionWithIdentifier:@"action!"
                                                               notification:expectedNotification
                                                         applicationState:UIApplicationStateActive
                                                   completionHandler:OCMOCK_ANY];


    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

    // Verify that the expected value is returned from combining the two results
    __block BOOL completionHandlerCalled;
    [self.delegate application:[UIApplication sharedApplication]
     handleActionWithIdentifier:@"action!"
  forRemoteNotification:expectedNotification
        completionHandler:^(){
            completionHandlerCalled = YES;
        }];

    XCTAssertTrue(pushCalled);
    XCTAssertTrue(completionHandlerCalled);
}


/*
 * Tests adding application:handleActionWithIdentifier:forRemoteNotification:completionHandler: calls
 * through to UAPush and the original delegate.
 */
- (void)testProxyAppReceivedActionWithIdentifier {
    XCTestExpectation *callBackFinished = [self expectationWithDescription:@"App delegate callback called"];

    NSDictionary *expectedNotification = @{@"oh": @"hi"};

    // Add implementation to the app delegate
    __block BOOL appDelegateCalled;
    [self addAppDelegateImplementation:@selector(application:handleActionWithIdentifier:forRemoteNotification:completionHandler:)
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
    __block BOOL pushCalled;
    void (^pushBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        pushCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^handler)() = (__bridge void (^)())arg;
        handler();
    };

    [[[self.mockPush stub] andDo:pushBlock] appReceivedActionWithIdentifier:@"action!"
                                                               notification:expectedNotification
                                                           applicationState:UIApplicationStateActive
                                                          completionHandler:OCMOCK_ANY];


    // Proxy the delegate
    [UAAppDelegateProxy proxyAppDelegate];

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
        XCTAssertTrue(pushCalled);
        XCTAssertTrue(completionHandlerCalled);
        XCTAssertTrue(appDelegateCalled);
    }];

}

/**
 * Adds a block based implementation to the app delegate with the given selector.
 *
 * @param selector A UIApplicationDelegate selector
 * @param block A block that matches the encoding of the selector. The first argument
 * must be self.
 */
- (void)addAppDelegateImplementation:(SEL)selector block:(id)block {
    struct objc_method_description description = protocol_getMethodDescription(@protocol(UIApplicationDelegate), selector, NO, YES);
    IMP implementation = imp_implementationWithBlock(block);
    class_addMethod(self.generatedClass, selector, implementation, description.types);
}

@end
