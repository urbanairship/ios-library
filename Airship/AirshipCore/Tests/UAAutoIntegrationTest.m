/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import <objc/runtime.h>
#import <UserNotifications/UserNotifications.h>
#import "UAAutoIntegration+Internal.h"
#import "UAAppIntegration.h"
#import "UAAppIntegration+Internal.h"

@interface UAAutoIntegrationTest : UABaseTest

@property (nonatomic, strong) id mockAppIntegration;
@property (nonatomic, strong) id delegate;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockUserNotificationCenter;
@property (nonatomic, strong) id notificationCenterDelegate;

@property (nonatomic, assign) Class GeneratedClassForAppDelegate;
@property (nonatomic, assign) Class GeneratedClassForNotificationCenterDelegate;
@end

@implementation UAAutoIntegrationTest

- (void)setUp {
    [super setUp];

    self.mockAppIntegration = [self mockForClass:[UAAppIntegration class]];

    // Generate a new class for each test run to avoid test pollution
    self.GeneratedClassForAppDelegate = objc_allocateClassPair([NSObject class], [[NSUUID UUID].UUIDString UTF8String], 0);
    objc_registerClassPair(self.GeneratedClassForAppDelegate);

    self.delegate = [[self.GeneratedClassForAppDelegate alloc] init];

    self.mockApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
    [[[self.mockApplication stub] andReturn:self.delegate] delegate];
    [[[self.mockApplication stub] andReturnValue:OCMOCK_VALUE(UIApplicationStateActive)] applicationState];

    self.mockUserNotificationCenter = [self mockForClass:[UNUserNotificationCenter class]];
    [[[self.mockUserNotificationCenter stub] andReturn:self.mockUserNotificationCenter] currentNotificationCenter];
}

- (void)tearDown {
    [UAAutoIntegration reset];

    self.delegate = nil;

    if (self.GeneratedClassForAppDelegate) {
        objc_disposeClassPair(self.GeneratedClassForAppDelegate);
    }

    if (self.GeneratedClassForNotificationCenterDelegate) {
        objc_disposeClassPair(self.GeneratedClassForNotificationCenterDelegate);
    }
    [self.mockUserNotificationCenter stopMocking];
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
    [self addImplementationForAppDelegateProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)
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
    [self addImplementationForAppDelegateProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
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
 * Tests proxying application:performFetchWithCompletionHandler
 */
- (void)testProxyBackgroundAppRefresh {
    // Add an implementation for application:didReceiveRemoteNotification:fetchCompletionHandler: that
    // calls an expected fetch result
    __block UIBackgroundFetchResult appDelegateResult;
    __block BOOL appDelegateCalled;

    [self addImplementationForAppDelegateProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:performFetchWithCompletionHandler:)
                                 block:^(id self, UIApplication *application, void (^completion)(UIBackgroundFetchResult) ) {

                                     appDelegateCalled = YES;

                                     // Verify the parameters
                                     XCTAssertEqualObjects([UIApplication sharedApplication], application);
                                     XCTAssertNotNil(completion);
                                     completion(appDelegateResult);
                                 }];

    // Add an implementation for UAPush that calls an expected fetch result
    __block UIBackgroundFetchResult fetchResult;
    __block BOOL fetchCalled;

    void (^fetchBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        fetchCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;
        handler(fetchResult);
        handler(fetchResult); // should handle being called multiple times
    };

    [[[self.mockAppIntegration stub] andDo:fetchBlock] application:self.mockApplication
                                 performFetchWithCompletionHandler:OCMOCK_ANY];

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
        fetchResult = allBackgroundFetchResults[i];

        for (int j = 0; j < 3; j++) {

            appDelegateCalled = NO;
            fetchCalled = NO;

            XCTestExpectation *callBackFinished = [self expectationWithDescription:@"Callback called"];
            UIBackgroundFetchResult expectedResult = expectedResults[i][j];

            // Set the app delegate result
            appDelegateResult = allBackgroundFetchResults[j];

            // Verify that the expected value is returned from combining the two results
            [self.delegate application:[UIApplication sharedApplication] performFetchWithCompletionHandler:^(UIBackgroundFetchResult result){
                XCTAssertEqual(expectedResult, result);
                [callBackFinished fulfill];
            }];

            // Wait for the test expectations
            [self waitForTestExpectations];
            XCTAssertTrue(fetchCalled);
            XCTAssertTrue(appDelegateCalled);
        }
    }

}

/*
 * Tests proxying application:didReceiveRemoteNotification:fetchCompletionHandler
 * responds with the combined value of the app delegate and UAAppHooks.
 */
- (void)testProxyAppReceivedRemoteNotificationWithCompletionHandler {
    NSDictionary *expectedNotification = @{@"oh": @"hi"};

    // Add an implementation for application:didReceiveRemoteNotification:fetchCompletionHandler: that
    // calls an expected fetch result
    __block UIBackgroundFetchResult appDelegateResult;
    __block BOOL appDelegateCalled;
    [self addImplementationForAppDelegateProtocol:@protocol(UIApplicationDelegate) selector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
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
            [self.delegate application:[UIApplication sharedApplication] didReceiveRemoteNotification:expectedNotification
                fetchCompletionHandler:^(UIBackgroundFetchResult result){
                    XCTAssertEqual(expectedResult, result);
                    [callBackFinished fulfill];
                }];

            // Wait for the test expectations
            [self waitForTestExpectations];

            XCTAssertTrue(pushCalled);
            XCTAssertTrue(appDelegateCalled);
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
        handler(UIBackgroundFetchResultNewData); // should handle being called multiple times

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

#pragma GCC diagnostic pop

#pragma UNUserNotificationCenterDelegate callbacks

- (void)testProxyWillPresentNotification {
    [self createnotificationCenterDelegate];
    
    XCTestExpectation *callBackFinished = [self expectationWithDescription:@"Notification Center delegate callback called"];
    
    id mockUNNotification = [self partialMockForObject:[UNNotification new]];
    [mockUNNotification setValue:[NSDate date] forKey:@"date"];
    
    UNNotificationPresentationOptions expectedOptions = UNNotificationPresentationOptionBadge;
    
    // Add implementation to the app delegate
    __block BOOL notificationCenterDelegateCalled = NO;
    [self addImplementationForNotificationCenterDelegateProtocol:@protocol(UNUserNotificationCenterDelegate) selector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)
                                                           block:^(id self, UNUserNotificationCenter *notificationCenter, UNNotification *notification, void (^completion)(UNNotificationPresentationOptions) ) {
                                                               notificationCenterDelegateCalled = YES;
                                                               
                                                               // Verify the parameters
                                                               XCTAssertEqualObjects([UNUserNotificationCenter currentNotificationCenter], notificationCenter);
                                                               XCTAssertEqualObjects(mockUNNotification, notification);
                                                               
                                                               XCTAssertNotNil(completion);
                                                               completion(expectedOptions);
                                                           }];
    
    // Stub the implementation for UAAppIntegration that handles userNotificationCenter:willPresentNotification:withCompletionHandler:
    // + (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler;
    __block BOOL appIntegrationForWillPresentNotificationCalled = NO;
    void (^appIntegrationForWillPresentNotificationBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        appIntegrationForWillPresentNotificationCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UNNotificationPresentationOptions) = (__bridge void (^)(UNNotificationPresentationOptions))arg;
        handler(expectedOptions);
        handler(expectedOptions); // should handle being called multiple times
    };
    
    [[[self.mockAppIntegration stub] andDo:appIntegrationForWillPresentNotificationBlock] userNotificationCenter:self.mockUserNotificationCenter
                                                                                         willPresentNotification:mockUNNotification
                                                                                           withCompletionHandler:OCMOCK_ANY];
    
    // Stub the implementation for UAAppIntegration that handles handleForegroundNotification:mergedOptions:withCompletionHandler:
    // + (void)handleForegroundNotification:(UNNotification *)notification mergedOptions:(UNNotificationPresentationOptions)options withCompletionHandler:(void(^)())completionHandler {
    __block BOOL appIntegrationForHandleForegroundNotificationCalled = NO;
    void (^appIntegrationForHandleForegroundNotificationBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        appIntegrationForHandleForegroundNotificationCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UNNotificationPresentationOptions) = (__bridge void (^)(UNNotificationPresentationOptions))arg;
        [invocation getArgument:&arg atIndex:3];
        UNNotificationPresentationOptions options = (UNNotificationPresentationOptions)arg;
        handler(options);
    };
    
    [[[self.mockAppIntegration stub] andDo:appIntegrationForHandleForegroundNotificationBlock] handleForegroundNotification:mockUNNotification
                                                                                  mergedOptions:expectedOptions
                                                                          withCompletionHandler:OCMOCK_ANY];
    
    // Proxy the delegate
    [UAAutoIntegration integrate];
    
    // Verify that the expected value is returned from combining the two results
    __block BOOL completionHandlerCalled = NO;
    [self.notificationCenterDelegate userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
                                    willPresentNotification:mockUNNotification
                                      withCompletionHandler:^(UNNotificationPresentationOptions options) {
                                          [callBackFinished fulfill];
                                          XCTAssertEqual(expectedOptions,options);
                                          completionHandlerCalled = YES;
                                      }];
    
    [self waitForTestExpectations];
    XCTAssertTrue(completionHandlerCalled);
    XCTAssertTrue(notificationCenterDelegateCalled);
    XCTAssertTrue(appIntegrationForWillPresentNotificationCalled);
    XCTAssertTrue(appIntegrationForHandleForegroundNotificationCalled);
}


- (void)testProxyDidReceiveNotificationResponse {
    [self createnotificationCenterDelegate];
    
    XCTestExpectation *callBackFinished = [self expectationWithDescription:@"Notification Centert delegate callback called"];
    
    NSString *actionIdentifier = @"test-action";
    id mockUNNotificationResponse = [self partialMockForObject:[UNNotificationResponse new]];
    [mockUNNotificationResponse setValue:actionIdentifier forKey:@"actionIdentifier"];
    
    // Add implementation to the app delegate
    __block BOOL notificationCenterDelegateCalled;
    [self addImplementationForNotificationCenterDelegateProtocol:@protocol(UNUserNotificationCenterDelegate) selector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)
                                                           block:^(id self, UNUserNotificationCenter *notificationCenter, UNNotificationResponse *response, void (^completion)(void) ) {
                                     notificationCenterDelegateCalled = YES;
                                     
                                     // Verify the parameters
                                     XCTAssertEqualObjects([UNUserNotificationCenter currentNotificationCenter], notificationCenter);
                                     XCTAssertEqualObjects(mockUNNotificationResponse, response);
                                     
                                     XCTAssertNotNil(completion);
                                     completion();
                                 }];
    
    
    // Stub the implementation for UAPush that calls an expected fetch result
    __block BOOL appIntegrationCalled;
    void (^appIntegrationBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
        appIntegrationCalled = YES;
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(void) = (__bridge void(^)(void))arg;
        handler();
        handler(); // should handle being called multiple times
    };
    
    [[[self.mockAppIntegration stub] andDo:appIntegrationBlock] userNotificationCenter:self.mockUserNotificationCenter
                                                        didReceiveNotificationResponse:mockUNNotificationResponse
                                                                 withCompletionHandler:OCMOCK_ANY];

    // Proxy the delegate
    [UAAutoIntegration integrate];
    
    // Verify that the expected value is returned from combining the two results
    __block BOOL completionHandlerCalled;
    [self.notificationCenterDelegate userNotificationCenter:[UNUserNotificationCenter currentNotificationCenter]
                             didReceiveNotificationResponse:mockUNNotificationResponse
                                      withCompletionHandler:^(){
                                          [callBackFinished fulfill];
                                          completionHandlerCalled = YES;
                                      }];
    
    [self waitForTestExpectations];
    XCTAssertTrue(completionHandlerCalled);
    XCTAssertTrue(notificationCenterDelegateCalled);
    XCTAssertTrue(appIntegrationCalled);
}


#pragma Helpers

/**
 * Adds a block based implementation to the app delegate with the given selector.
 *
 * @param protocol The protocol to which the implementation will be added.
 * @param selector A selector for the given protocol
 * @param block A block that matches the encoding of the selector. The first argument
 * must be self.
 */
- (void)addImplementationForAppDelegateProtocol:(id)protocol selector:(SEL)selector block:(id)block {
    struct objc_method_description description = protocol_getMethodDescription(protocol, selector, NO, YES);
    IMP implementation = imp_implementationWithBlock(block);
    class_addMethod(self.GeneratedClassForAppDelegate, selector, implementation, description.types);
}

/**
 * Adds a block based implementation to the notification center delegate with the given selector.
 *
 * @param protocol The protocol to which the implementation will be added.
 * @param selector A selector for the given protocol
 * @param block A block that matches the encoding of the selector. The first argument
 * must be self.
 */
- (void)addImplementationForNotificationCenterDelegateProtocol:(id)protocol selector:(SEL)selector block:(id)block {
    struct objc_method_description description = protocol_getMethodDescription(protocol, selector, NO, YES);
    IMP implementation = imp_implementationWithBlock(block);
    class_addMethod(self.GeneratedClassForNotificationCenterDelegate, selector, implementation, description.types);
}

- (void) createnotificationCenterDelegate {
    // Generate a new class for each test run to avoid test pollution
    self.GeneratedClassForNotificationCenterDelegate = objc_allocateClassPair([NSObject class], [[NSUUID UUID].UUIDString UTF8String], 0);
    objc_registerClassPair(self.GeneratedClassForNotificationCenterDelegate);
    
    self.notificationCenterDelegate = [[self.GeneratedClassForNotificationCenterDelegate alloc] init];
    
    [[[self.mockUserNotificationCenter stub] andReturn:self.notificationCenterDelegate] delegate];
}
@end
