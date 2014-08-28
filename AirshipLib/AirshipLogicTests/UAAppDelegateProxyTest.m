#import <XCTest/XCTest.h>
#import "UAAppDelegateProxy.h"
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAirship.h"

typedef void (^MethodBlock)(NSInvocation *);

@interface TestAppDelegateSurrogate : NSObject<UIApplicationDelegate>
@property (nonatomic, strong) NSMutableDictionary *methodBlocks;
- (void)addMethodBlock:(MethodBlock)methodBlock forSelectorString:(NSString *)selector;
@end

@interface UAAppDelegateProxyTest : XCTestCase
@property (nonatomic, strong) UAAppDelegateProxy *baseDelegate;
@property (nonatomic, strong) TestAppDelegateSurrogate *airshipDelegate;
@property (nonatomic, strong) TestAppDelegateSurrogate *originalDelegate;
@end

@implementation UAAppDelegateProxyTest

- (void)setUp {
    [super setUp];
    self.baseDelegate = [[UAAppDelegateProxy alloc] init];
    self.airshipDelegate = [[TestAppDelegateSurrogate alloc] init];
    self.originalDelegate = [[TestAppDelegateSurrogate alloc] init];

    self.baseDelegate.airshipAppDelegate = self.airshipDelegate;
    self.baseDelegate.originalAppDelegate = self.originalDelegate;
}

- (void)tearDown {
    [super tearDown];
}

/*
 * Test that responds to selector checks airshipDelegate, originalAppDelegate, and its
 * self for a given selector.
 */
- (void)testRespondsToSelector {
    // Add a method that only the airshipDelegate responds to
    [self.airshipDelegate addMethodBlock:^(NSInvocation *invocation) { }
                         forSelectorString:@"someRandomMethod"];

    // Add a method that only the originalDelegate responds to
    [self.originalDelegate addMethodBlock:^(NSInvocation *invocation) { }
                       forSelectorString:@"someOtherRandomMethod"];

    // Verify that it responds to methods that the airshipDelegate responds to
    XCTAssertTrue([self.baseDelegate respondsToSelector:NSSelectorFromString(@"someRandomMethod")],
                  @"respondsToSelector does not respond for its airshipAppDelegate methods");

    // Verify that it responds to methods that the originalAppDelegate responds to
    XCTAssertTrue([self.baseDelegate respondsToSelector:NSSelectorFromString(@"someOtherRandomMethod")],
                  @"respondsToSelector does not respond for its originalAppDelegate methods");

    // Verify it doesnt just respond to everything
    XCTAssertFalse([self.baseDelegate respondsToSelector:NSSelectorFromString(@"someUndefinedMethod")],
                   @"respondsToSelector responds to methods that are not defined");
}

/*
 * Test that application:didReceiveRemoteNotification:fetchCompletionHandler: only responds if background push is enabled
 * or the originalAppDelegate responds
 */
- (void)testRespondsToSelectorApplicationDidReceiveRemoteNotificationFetchCompletionHandler {
    id mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[mockAirship stub] andReturn:mockAirship] shared];
    [[[mockAirship expect] andReturnValue:OCMOCK_VALUE(NO)] remoteNotificationBackgroundModeEnabled];

    // Verify it does not respond when background notifications is disabled and the app delegate does not respond
    XCTAssertFalse([self.baseDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)],
                   @"respondsToSelector should not respond to application:didReceiveRemoteNotification:fetchCompletionHandler: when background push is disabled and originalAppDelegate does not respond");

    // Verify it does respond when background notifications is enabled
    [[[mockAirship expect] andReturnValue:OCMOCK_VALUE(YES)] remoteNotificationBackgroundModeEnabled];

    XCTAssertTrue([self.baseDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)],
                  @"respondsToSelector should respond to application:didReceiveRemoteNotification:fetchCompletionHandler: when background push is enabled");

    // Verify it responds when background notifications is disabled but the app delegate responds
    [[[mockAirship expect] andReturnValue:OCMOCK_VALUE(NO)] remoteNotificationBackgroundModeEnabled];

    [self.originalDelegate addMethodBlock:^(NSInvocation *invocation) { }
                       forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];

     XCTAssertTrue([self.baseDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)],
                   @"respondsToSelector should respond to application:didReceiveRemoteNotification:fetchCompletionHandler: when the app delegate responds");

    [mockAirship stopMocking];
}

/*
 * Tests that an exception is raised if the originalAppDelegate is nil
 */
- (void)testForwardInvocationNoOriginalAppDelegate {
    self.baseDelegate.originalAppDelegate = nil;

    id mockedInvocation = [OCMockObject niceMockForClass:[NSInvocation class]];
    [mockedInvocation setSelector:NSSelectorFromString(@"someRandomMethod")];

    XCTAssertThrows([self.baseDelegate forwardInvocation:mockedInvocation],
                    @"UAAppDelegateProxy should raise an exception if the original app delegate is nil");
    [mockedInvocation stopMocking];
}

/*
 * Tests that it neither of the delegates respond, it still forwards
 * the invocation to the originalAppDelegate
 */
- (void)testForwardInvocationNoResponse {
    // Set up a mocked invocation that expects to be invoked with the originalAppDelegate
    id mockedInvocation = [OCMockObject niceMockForClass:[NSInvocation class]];
    [[[mockedInvocation stub] andReturnValue:OCMOCK_VALUE(NSSelectorFromString(@"someRandomMethod"))] selector];
    [[mockedInvocation expect] invokeWithTarget:self.originalDelegate];

    [self.baseDelegate forwardInvocation:mockedInvocation];
    XCTAssertNoThrow([mockedInvocation verify],
                     @"UAAppDelegateProxy should still forward invocations to the original app delegate if neither delegate responds");

    [mockedInvocation stopMocking];
}

/*
 * Tests that it invokes invocations on the sub delegates if only
 * one respond to a given selector
 */
- (void)testForwardInvocationOneDelegateResponds {
    // Add a method block that only one the surrgateDelegate will respond to
    [self.airshipDelegate addMethodBlock:^(NSInvocation *invocation) { }
                         forSelectorString:@"someOtherRandomMethod"];

    // Set up a mocked invocation that expects to be invoked with only one delegate
    id mockedInvocation = [OCMockObject niceMockForClass:[NSInvocation class]];
    [[[mockedInvocation stub] andReturnValue:OCMOCK_VALUE(NSSelectorFromString(@"someOtherRandomMethod"))] selector];
    [[mockedInvocation reject] invokeWithTarget:self.originalDelegate];
    [[mockedInvocation expect] invokeWithTarget:self.airshipDelegate];

    // Verify only the airshipDelegate was invoked
    XCTAssertNoThrow([self.baseDelegate forwardInvocation:mockedInvocation],
                     @"UAAppDelegateProxy is invoking with both delegates when it should only be sending to the airship app delegate");

    XCTAssertNoThrow([mockedInvocation verify],
                     @"UAAppDelegateProxy should only send to the airship app delegate");

    [mockedInvocation stopMocking];
}

/*
 * Tests that it invokes invocations on the sub delegates if only
 * one respond to a given selector
 */
- (void)testForwardInvocationBothDelegatesResponds {
    // Add same method blocks to the sub delegates so they will respond to different selectors
    [self.airshipDelegate addMethodBlock:^(NSInvocation *invocation) { }
                         forSelectorString:@"someRandomMethod"];

    [self.originalDelegate addMethodBlock:^(NSInvocation *invocation) { }
                       forSelectorString:@"someRandomMethod"];

    // Set up a mocked invocation that expects to be invoked with both delegates
    id mockedInvocation = [OCMockObject niceMockForClass:[NSInvocation class]];
    [[[mockedInvocation stub] andReturnValue:OCMOCK_VALUE(NSSelectorFromString(@"someRandomMethod"))] selector];
    [[mockedInvocation expect] invokeWithTarget:self.originalDelegate];
    [[mockedInvocation expect] invokeWithTarget:self.airshipDelegate];

    // Verify both delegates are invoked with the invocation
    [self.baseDelegate forwardInvocation:mockedInvocation];
    XCTAssertNoThrow([mockedInvocation verify],
                     @"UAAppDelegateProxy did not invoke both delegates");

    [mockedInvocation stopMocking];
}

/*
 * Tests application:didReceiveRemoteNotification:fetchCompletionHandler 
 * responds with UIBackgroundFetchResultNoData if neither of the app delegates respond
 */
- (void)testDidReceiveRemoteNotificationNoSubDelegateResponse {
    [self.baseDelegate application:nil didReceiveRemoteNotification:nil fetchCompletionHandler:^(UIBackgroundFetchResult result){
        XCTAssertEqual(UIBackgroundFetchResultNoData, result, @"application:didReceiveRemoteNotification:fetchCompletionHandler should return no data as a default value");
    }];
}

/*
 * Tests application:didReceiveRemoteNotification:fetchCompletionHandler
 * responds with the combined value of the sub delegates
 */
- (void)testDidReceiveRemoteNotificationBothSubDelegateResponses {

    UIBackgroundFetchResult allBackgroundFetchResults[] = {UIBackgroundFetchResultNoData, UIBackgroundFetchResultFailed, UIBackgroundFetchResultNewData};

    // The expected matrix from the different combined values of allBackgroundFetchResults indicies
    UIBackgroundFetchResult expectedResults[3][3] = {
        {UIBackgroundFetchResultNoData, UIBackgroundFetchResultFailed, UIBackgroundFetchResultNewData},
        {UIBackgroundFetchResultFailed, UIBackgroundFetchResultFailed, UIBackgroundFetchResultNewData},
        {UIBackgroundFetchResultNewData, UIBackgroundFetchResultNewData, UIBackgroundFetchResultNewData}
    };

    for (int i = 0; i < 3; i++) {

        // Set the defualtDelegate to return a result for application:didReceiveRemoteNotification:fetchCompletionHandler:
        __block UIBackgroundFetchResult originalAppDelegateResult = allBackgroundFetchResults[i];
        [self.originalDelegate addMethodBlock:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:4];
            void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;
            handler(originalAppDelegateResult);
        } forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];

        for (int j = 0; j < 3; j++) {

            // Set the airshipDelegate to return a result for application:didReceiveRemoteNotification:fetchCompletionHandler:
            __block UIBackgroundFetchResult surrogateDelagateResult = allBackgroundFetchResults[j];
            [self.airshipDelegate addMethodBlock:^(NSInvocation *invocation) {
                void *arg;
                [invocation getArgument:&arg atIndex:4];
                void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;
                handler(surrogateDelagateResult);
            } forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];

            // Verify that the expected value is returned from combining the two delegate results
            __block UIBackgroundFetchResult expectedResult = expectedResults[i][j];
            [self.baseDelegate application:nil didReceiveRemoteNotification:nil fetchCompletionHandler:^(UIBackgroundFetchResult result){
                XCTAssertEqual(expectedResult, result,
                               @"application:didReceiveRemoteNotification:fetchCompletionHandler should return %@ when airship app delegate returns %@ and original app delegate returns %@",
                               [self stringFromBackgroundFetchResult:expectedResult],
                               [self stringFromBackgroundFetchResult:surrogateDelagateResult],
                               [self stringFromBackgroundFetchResult:originalAppDelegateResult]);
            }];
        }
    }
}

/*
 * Tests application:handleActionWithIdentifier:forRemoteNotification:completionHandler
 * calls both delegates if they responds and only calls the completion handler
 * once after each delegate is finished.
 */
- (void)testHandleAction {

    __block BOOL callbackCalled = NO;
    __block BOOL originalDelegateCalled = NO;
    __block BOOL airshipDelegateCalled = NO;

    // Neither app delegates respond
    [self.baseDelegate application:nil handleActionWithIdentifier:@"id" forRemoteNotification:nil completionHandler:^{
        callbackCalled = YES;
    }];

    XCTAssertTrue(callbackCalled, @"The proxy delegate should call the completion handler if no app delegates respond to the method.");

    // One app delegate responds
    callbackCalled = NO;

    [self.originalDelegate addMethodBlock:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^handler)() = (__bridge void (^)())arg;

        originalDelegateCalled = YES;
        handler();
    } forSelectorString:@"application:handleActionWithIdentifier:forRemoteNotification:completionHandler:"];

    [self.baseDelegate application:nil handleActionWithIdentifier:@"id" forRemoteNotification:nil completionHandler:^{
        callbackCalled = YES;
    }];

    XCTAssertTrue(callbackCalled, @"The proxy delegate should call the completion handler after sub delegates finish.");
    XCTAssertTrue(originalDelegateCalled, @"The original delegate should be called with the app delegate.");


    // Both app delegates respond
    callbackCalled = NO;
    originalDelegateCalled = NO;
    airshipDelegateCalled = NO;

    [self.airshipDelegate addMethodBlock:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:5];
        void (^handler)() = (__bridge void (^)())arg;

        airshipDelegateCalled = YES;
        handler();
    } forSelectorString:@"application:handleActionWithIdentifier:forRemoteNotification:completionHandler:"];


    [self.baseDelegate application:nil handleActionWithIdentifier:@"id" forRemoteNotification:nil completionHandler:^{
        callbackCalled = YES;
    }];

    XCTAssertTrue(callbackCalled, @"The proxy delegate should call the completion handler after sub delegates finish.");
    XCTAssertTrue(originalDelegateCalled, @"The selector should be called on the original delegate.");
    XCTAssertTrue(airshipDelegateCalled, @"The selector should be called on the airship delegate.");

}

-(NSString *)stringFromBackgroundFetchResult:(UIBackgroundFetchResult)result {
    switch(result) {
        case UIBackgroundFetchResultFailed:
            return @"UIBackgroundFetchResultFailed";
        case UIBackgroundFetchResultNewData:
            return @"UIBackgroundFetchResultNewData";
        case UIBackgroundFetchResultNoData:
            return  @"UIBackgroundFetchResultNoData";
        default:
            return @"UKNOWN";
    }
}

/*
 * Tests application:didReceiveRemoteNotification:fetchCompletionHandler
 * responds with the results of the single delegate that responds
 */
- (void)testDidReceiveRemoteNotificationOneSubDelegateResponse {
    [self.airshipDelegate addMethodBlock:^(NSInvocation *invocation) {
        void *arg;
        // Do magic to get the block from the NSInvocation.  Index 4 because the first 2 arguments are hidden arguments - self and command
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;

        // Call handler with UIBackgroundFetchResultNewData result
        handler(UIBackgroundFetchResultNewData);
    } forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];

    [self.baseDelegate application:nil didReceiveRemoteNotification:nil fetchCompletionHandler:^(UIBackgroundFetchResult result){
        XCTAssertEqual(UIBackgroundFetchResultNewData, result,
                       @"application:didReceiveRemoteNotification:fetchCompletionHandler should return no data as a default value");
    }];
}


/*
 * Test calling completion handlers application:didReceiveRemoteNotification:fetchCompletionHandler
 * multiple times are ignored
 */
- (void)testDidReceiveRemoteNotificationCallingCompletionHandlerMultipleTimes {

    // Define application:didReceiveRemoteNotification:fetchCompletionHandler: that calls the completion
    // handler multiple times on both delegates.
    
    [self.airshipDelegate addMethodBlock:^(NSInvocation *invocation) {
        void *arg;
        // Do magic to get the block from the NSInvocation.  Index 4 because the first 2 arguments are hidden arguments - self and command
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;

        // Call the handler multiple times
        handler(UIBackgroundFetchResultNoData);
        handler(UIBackgroundFetchResultNewData);
    } forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];

    [self.originalDelegate addMethodBlock:^(NSInvocation *invocation) {
        void *arg;
        // Do magic to get the block from the NSInvocation.  Index 4 because the first 2 arguments are hidden arguments - self and command
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;

        // Call the handler multiple times
        handler(UIBackgroundFetchResultNoData);
        handler(UIBackgroundFetchResultNewData);
    } forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];


    [self.baseDelegate application:nil didReceiveRemoteNotification:nil fetchCompletionHandler:^(UIBackgroundFetchResult result){
        XCTAssertEqual(UIBackgroundFetchResultNoData, result, @"application:didReceiveRemoteNotification:fetchCompletionHandler should ignore multiple calls to the completion handler");
    }];
}

- (void)testAirshipDelegateDoesNotReceiveNSObjectMessages {

    SEL selector = @selector(performSelectorOnMainThread:withObject:waitUntilDone:);

    // Set up a mocked invocation that expects to be invoked with both delegates
    id mockedInvocation = [OCMockObject niceMockForClass:[NSInvocation class]];
    [[[mockedInvocation stub] andReturnValue:OCMOCK_VALUE(selector)] selector];
    [[mockedInvocation expect] invokeWithTarget:self.originalDelegate];
    [[mockedInvocation reject] invokeWithTarget:self.airshipDelegate];

    [self.baseDelegate forwardInvocation:mockedInvocation];
    XCTAssertNoThrow([mockedInvocation verify],
                     @"UAAppDelegateProxy did send NSObject methods only to the original app delegate");
}

@end


@implementation TestAppDelegateSurrogate

- (id)init {
    self = [super init];
    if (self) {
        self.methodBlocks = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)selector {
    return self.methodBlocks[NSStringFromSelector(selector)] != nil;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    MethodBlock methodBlock = [self.methodBlocks valueForKey:NSStringFromSelector([invocation selector])];

    if (methodBlock) {
        methodBlock(invocation);
    } else {
        [super forwardInvocation:invocation];
    }
}

- (void)addMethodBlock:(MethodBlock)methodBlock forSelectorString:(NSString *)selector {
    [self.methodBlocks setObject:[methodBlock copy] forKey:selector];
}

@end