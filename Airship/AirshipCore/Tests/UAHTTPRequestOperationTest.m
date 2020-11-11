/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAHTTPRequestOperation+Internal.h"

@interface UAHTTPRequestOperationTest : UABaseTest
@property (nonatomic, strong) UARequest *request;
@property (nonatomic, strong) id mockSession;
@end

@implementation UAHTTPRequestOperationTest

- (void)setUp {
    [super setUp];
    self.request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        builder.URL = [NSURL URLWithString:@"https://testing.one.two.three"];
    }];
    self.mockSession = [self mockForClass:[UARequestSession class]];
}

- (void)testDefaults {
    UAHTTPRequestOperation *operation = [UAHTTPRequestOperation operationWithRequest:self.request
                                                                             session:self.mockSession
                                                                 completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {}];

    XCTAssertEqual(operation.isAsynchronous, YES);
    XCTAssertEqual(operation.isExecuting, NO);
    XCTAssertEqual(operation.isCancelled, NO);
    XCTAssertEqual(operation.isFinished, NO);
}

- (void)testOperation {
    NSData *testData = [NSData data];
    NSHTTPURLResponse *testResponse = [[NSHTTPURLResponse alloc] init];
    NSError *testError = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];

    __block BOOL operationFinished = NO;

    UAHTTPRequestOperation *operation = [UAHTTPRequestOperation operationWithRequest:self.request
                                                                           session:self.mockSession
                                                                 completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                                                                     XCTAssertEqual(testData, data);
                                                                     XCTAssertEqual(testResponse, response);
                                                                     XCTAssertEqual(testError, error);
                                                                     operationFinished = YES;
                                                                 }];


    XCTestExpectation *operationPerformedRequest = [self expectationWithDescription:@"operation performed request"];

    // Expect a call and capture the callback and fulfill the test expectation
    __block void (^completionHandler)(NSData *, NSURLResponse *, NSError *) = nil;
    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        completionHandler = (__bridge void (^)(NSData *, NSURLResponse *, NSError *))arg;
        [operationPerformedRequest fulfill];
    }] performHTTPRequest:self.request completionHandler:OCMOCK_ANY];

    // Start the operation
    [operation start];

    // Should be in flight
    XCTAssertEqual(operation.isExecuting, YES);
    XCTAssertEqual(operation.isFinished, NO);
    XCTAssertEqual(operationFinished, NO);

    // Wait for the operation to call the request
    [self waitForTestExpectations];

    // Call the completion handler
    completionHandler(testData, testResponse, testError);

    // Operation should be finished
    XCTAssertEqual(operation.isExecuting, NO);
    XCTAssertEqual(operation.isFinished, YES);
    XCTAssertEqual(operationFinished, YES);
}

- (void)testCancel {
    UAHTTPRequestOperation *operation = [UAHTTPRequestOperation operationWithRequest:self.request
                                                                             session:self.mockSession
                                                                   completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {}];

    XCTestExpectation *disposableCalled = [self expectationWithDescription:@"dispoable called"];
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        [disposableCalled fulfill];
    }];
    [[[self.mockSession expect] andReturn:disposable] performHTTPRequest:self.request completionHandler:OCMOCK_ANY];

    [operation start];
    [operation cancel];
    [self waitForTestExpectations];
    XCTAssertEqual(operation.isCancelled, YES);
}

- (void)testPreemptiveCancel {
    UAHTTPRequestOperation *operation = [UAHTTPRequestOperation operationWithRequest:self.request
                                                                             session:self.mockSession
                                                                   completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {}];
    [operation cancel];
    XCTAssertEqual(operation.isCancelled, YES);

    [operation start];
    XCTAssertEqual(operation.isExecuting, NO);
    XCTAssertEqual(operation.isFinished, YES);
}

@end
