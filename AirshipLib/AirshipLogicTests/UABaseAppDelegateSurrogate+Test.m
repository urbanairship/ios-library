#import <XCTest/XCTest.h>
#import "UABaseAppDelegateSurrogate.h"
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>

typedef void (^MethodBlock)(NSInvocation *);

@interface TestAppDelegateSurrogate : NSObject<UIApplicationDelegate>
@property (nonatomic, strong) NSMutableDictionary *methodBlocks;
- (void)addMethodBlock:(MethodBlock)methodBlock forSelectorString:(NSString *)selector;
@end

@interface UABaseAppDelegateSurrogate_Test : XCTestCase
@property(nonatomic, strong) UABaseAppDelegateSurrogate *baseDelegate;
@property(nonatomic, strong) TestAppDelegateSurrogate *surrogateDelegate;
@property(nonatomic, strong) TestAppDelegateSurrogate *defaultDelegate;
@end

@implementation UABaseAppDelegateSurrogate_Test

- (void)setUp {
    [super setUp];
    self.baseDelegate = [[UABaseAppDelegateSurrogate alloc] init];
    self.surrogateDelegate = [[TestAppDelegateSurrogate alloc] init];
    self.defaultDelegate = [[TestAppDelegateSurrogate alloc] init];

    self.baseDelegate.surrogateDelegate = self.surrogateDelegate;
    self.baseDelegate.defaultAppDelegate = self.defaultDelegate;
}

- (void)tearDown {
    [super tearDown];
}

/*
 * Test that responds to selector checks surrogateDelegate, defaultAppDelegate, and its
 * self for a given selector.
 */
- (void)testRespondsToSelector {
    // Add a method that only the surrogateDelegate responds to
    [self.surrogateDelegate addMethodBlock:^(NSInvocation *invocation) { } forSelectorString:@"someRandomMethod"];

    // Add a method that only the defaultDelegate responds to
    [self.defaultDelegate addMethodBlock:^(NSInvocation *invocation) { } forSelectorString:@"someOtherRandomMethod"];

    // Verify that it responds to methods only the baseDelegate responds to
    XCTAssertTrue([self.baseDelegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)], @"respondsToSelector does not respond for its own methods");

    // Verify that it responds to methods that the surrogateDelegate responds to
    XCTAssertTrue([self.baseDelegate respondsToSelector:NSSelectorFromString(@"someRandomMethod")], @"respondsToSelector does not respond for its surrgoteDelegate methods");

    // Verify that it responds to methods that the defaultAppDelegate responds to
    XCTAssertTrue([self.baseDelegate respondsToSelector:NSSelectorFromString(@"someOtherRandomMethod")], @"respondsToSelector does not respond for its defaultAppDelegate methods");

    // Verify it doesnt just respond to everything
    XCTAssertFalse([self.baseDelegate respondsToSelector:NSSelectorFromString(@"someUndefinedMethod")], @"respondsToSelector responds to methods that are not defined");
}

/*
 * Tests that an exception is raised if the defualtAppDelegate is nil
 */
- (void)testForwardInvocationNoDefaultAppDelegate {
    self.baseDelegate.defaultAppDelegate = nil;

    id mockedInvocation = [OCMockObject niceMockForClass:[NSInvocation class]];
    [mockedInvocation setSelector:NSSelectorFromString(@"someRandomMethod")];

    XCTAssertThrows([self.baseDelegate forwardInvocation:mockedInvocation], @"UABaseAppDelegateSurrogate should raise an exception if the default app delegate is nil");
}

/*
 * Tests that it neither of the delegates respond, it still forwards
 * the invocation to the defaultAppDelegate
 */
- (void)testForwardInvocationNoResponse {
    // Set up a mocked invocation that expects to be invoked with the defaultAppDelegate
    id mockedInvocation = [OCMockObject niceMockForClass:[NSInvocation class]];
    [[[mockedInvocation stub] andReturnValue:OCMOCK_VALUE(NSSelectorFromString(@"someRandomMethod"))] selector];
    [[mockedInvocation expect] invokeWithTarget:self.defaultDelegate];

    [self.baseDelegate forwardInvocation:mockedInvocation];
    XCTAssertNoThrow([mockedInvocation verify], @"UABaseAppDelegate should still forward invocations to the base app delegate if neither delegate responds");
    [mockedInvocation stopMocking];
}

/*
 * Tests that it invokes invocations on the sub delegates if only
 * one respond to a given selector
 */
- (void)testForwardInvocationOneDelegateResponds {
    // Add a method block that only one the surrgateDelegate will respond to
    [self.surrogateDelegate addMethodBlock:^(NSInvocation *invocation) { } forSelectorString:@"someOtherRandomMethod"];

    // Set up a mocked invocation that expects to be invoked with only one delegate
    id mockedInvocation = [OCMockObject niceMockForClass:[NSInvocation class]];
    [[[mockedInvocation stub] andReturnValue:OCMOCK_VALUE(NSSelectorFromString(@"someOtherRandomMethod"))] selector];
    [[mockedInvocation reject] invokeWithTarget:self.defaultDelegate];
    [[mockedInvocation expect] invokeWithTarget:self.surrogateDelegate];

    // Verify only the surrogateDelegate was invoked
    XCTAssertNoThrow([self.baseDelegate forwardInvocation:mockedInvocation], @"UABaseAppDelegate is invoking with both delegates when it should only be with the surrogateDelegate");
    XCTAssertNoThrow([mockedInvocation verify], @"UABaseAppDelegate did not only the surrogate delegate");
    [mockedInvocation stopMocking];
}

/*
 * Tests that it invokes invocations on the sub delegates if only
 * one respond to a given selector
 */
- (void)testForwardInvocationBothDelegatesResponds {
    // Add same method blocks to the sub delegates so they will respond to different selectors
    [self.surrogateDelegate addMethodBlock:^(NSInvocation *invocation) { } forSelectorString:@"someRandomMethod"];
    [self.defaultDelegate addMethodBlock:^(NSInvocation *invocation) { } forSelectorString:@"someRandomMethod"];

    // Set up a mocked invocation that expects to be invoked with both delegates
    id mockedInvocation = [OCMockObject niceMockForClass:[NSInvocation class]];
    [[[mockedInvocation stub] andReturnValue:OCMOCK_VALUE(NSSelectorFromString(@"someRandomMethod"))] selector];
    [[mockedInvocation expect] invokeWithTarget:self.defaultDelegate];
    [[mockedInvocation expect] invokeWithTarget:self.surrogateDelegate];

    // Verify both delegates are invoked with the invocation
    [self.baseDelegate forwardInvocation:mockedInvocation];
    XCTAssertNoThrow([mockedInvocation verify], @"UABaseAppDelegate did not invoke both delegates");
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

    __block UIBackgroundFetchResult allBackgroundFetchResults[] = {UIBackgroundFetchResultNoData, UIBackgroundFetchResultFailed, UIBackgroundFetchResultNewData};

    // The expected matrix from the different combined values of allBackgroundFetchResults indicies
    UIBackgroundFetchResult expectedResults[3][3] = {
        {UIBackgroundFetchResultNoData, UIBackgroundFetchResultFailed, UIBackgroundFetchResultNewData},
        {UIBackgroundFetchResultFailed, UIBackgroundFetchResultFailed, UIBackgroundFetchResultNewData},
        {UIBackgroundFetchResultNewData, UIBackgroundFetchResultNewData, UIBackgroundFetchResultNewData}
    };

    for (int i = 0; i < 3; i++) {

        // Set the defualtDelegate to return a result for application:didReceiveRemoteNotification:fetchCompletionHandler:
        __block UIBackgroundFetchResult defaultAppDelegateResult = allBackgroundFetchResults[i];
        [self.defaultDelegate addMethodBlock:^(NSInvocation *invocation) {
            void *arg;
            [invocation getArgument:&arg atIndex:4];
            void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;
            handler(defaultAppDelegateResult);
        } forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];

        for (int j = 0; j < 3; j++) {

            // Set the surrogateDelegate to return a result for application:didReceiveRemoteNotification:fetchCompletionHandler:
            __block UIBackgroundFetchResult surrogateDelagateResult = allBackgroundFetchResults[j];
            [self.surrogateDelegate addMethodBlock:^(NSInvocation *invocation) {
                void *arg;
                [invocation getArgument:&arg atIndex:4];
                void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;
                handler(surrogateDelagateResult);
            } forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];

            // Verify that the expected value is returned from combining the two delegate results
            __block UIBackgroundFetchResult expectedResult = expectedResults[i][j];
            [self.baseDelegate application:nil didReceiveRemoteNotification:nil fetchCompletionHandler:^(UIBackgroundFetchResult result){
                XCTAssertEqual(expectedResult, result,
                               @"application:didReceiveRemoteNotification:fetchCompletionHandler should return %@ when surrogateDelate returns %@ and defaultAppDelegate returns %@",
                               [self stringFromBackgroundFetchResult:expectedResult],
                               [self stringFromBackgroundFetchResult:surrogateDelagateResult],
                               [self stringFromBackgroundFetchResult:defaultAppDelegateResult]);
            }];
        }
    }
}



-(NSString *)stringFromBackgroundFetchResult:(UIBackgroundFetchResult)result {
    if (result == UIBackgroundFetchResultFailed) {
        return @"UIBackgroundFetchResultFailed";
    }
    if (result == UIBackgroundFetchResultNewData) {
        return @"UIBackgroundFetchResultNewData";
    }
    if (result == UIBackgroundFetchResultNoData) {
        return @"UIBackgroundFetchResultNoData";
    }
    return @"UNKNOWN";
}

/*
 * Tests application:didReceiveRemoteNotification:fetchCompletionHandler
 * responds with the results of the single delegate that responds
 */
- (void)testDidReceiveRemoteNotificationOneSubDelegateResponse {
    [self.surrogateDelegate addMethodBlock:^(NSInvocation *invocation) {
        void *arg;
        // Do magic to get the block from the NSInvocation.  Index 4 because the first 2 arguments are hidden arguments - self and command
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;

        // Call handler with UIBackgroundFetchResultNewData result
        handler(UIBackgroundFetchResultNewData);
    } forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];

    [self.baseDelegate application:nil didReceiveRemoteNotification:nil fetchCompletionHandler:^(UIBackgroundFetchResult result){
        XCTAssertEqual(UIBackgroundFetchResultNewData, result, @"application:didReceiveRemoteNotification:fetchCompletionHandler should return no data as a default value");
    }];
}


/*
 * Test calling completion handlers application:didReceiveRemoteNotification:fetchCompletionHandler
 * multiple times are ignored
 */
- (void)testDidReceiveRemoteNotificationCallingCompletionHandlerMultipleTimes {

    // Define application:didReceiveRemoteNotification:fetchCompletionHandler: that calls the completion
    // handler multiple times on both delegates.
    
    [self.surrogateDelegate addMethodBlock:^(NSInvocation *invocation) {
        void *arg;
        // Do magic to get the block from the NSInvocation.  Index 4 because the first 2 arguments are hidden arguments - self and command
        [invocation getArgument:&arg atIndex:4];
        void (^handler)(UIBackgroundFetchResult result) = (__bridge void (^)(UIBackgroundFetchResult))arg;

        // Call the handler multiple times
        handler(UIBackgroundFetchResultNoData);
        handler(UIBackgroundFetchResultNewData);
    } forSelectorString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"];

    [self.defaultDelegate addMethodBlock:^(NSInvocation *invocation) {
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
    MethodBlock methodBlock = [self.methodBlocks valueForKey:NSStringFromSelector(selector)];

    return methodBlock != nil;
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