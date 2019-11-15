/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UARequestSession.h"
#import "UAURLRequestOperation+Internal.h"
#import "UADelayOperation+Internal.h"

@interface UARequestSessionTest : UABaseTest
@property (nonatomic, strong) id mockNSURLSession;
@property (nonatomic, strong) id mockQueue;
@property (nonatomic, strong) UARequestSession *session;
@end

@implementation UARequestSessionTest

- (void)setUp {
    [super setUp];

    self.mockQueue = [self mockForClass:[NSOperationQueue class]];

    // Stub the queue to run UAURLRequestOperation immediately
    [[[self.mockQueue stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSOperation *operation = (__bridge NSOperation *)arg;
        [operation start];
    }] addOperation:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAURLRequestOperation class]];
    }]];

    self.mockNSURLSession = [self mockForClass:[NSURLSession class]];
    self.session = [UARequestSession sessionWithConfig:self.config
                                          NSURLSession:self.mockNSURLSession
                                                 queue:self.mockQueue];
}

- (void)testDataTask {
     // Create a test request
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
        builder.URL = [NSURL URLWithString:@"www.urbanairship.com"];
        builder.username = @"name";
        builder.password = @"password";
        [builder setValue:@"header_value" forHeader:@"header_key"];
    }];

    // Expect a call to the NSURLSession and capture the callback
    __block UARequestCompletionHandler completionHandler;
    [(NSURLSession *)[[self.mockNSURLSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        completionHandler = (__bridge UARequestCompletionHandler)arg;
    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURLRequest *urlRequest = (NSURLRequest *)obj;

        if (![urlRequest.HTTPMethod isEqualToString:request.method]) {
            return NO;
        }

        if (![urlRequest.URL isEqual:request.URL]) {
            return NO;
        }

        if (![urlRequest.HTTPBody isEqualToData:request.body]) {
            return NO;
        }

        for (id key in request.headers) {
            if (![request.headers[key] isEqualToString:urlRequest.allHTTPHeaderFields[key]]) {
                return NO;
            }
        }

        return YES;
    }] completionHandler:OCMOCK_ANY];

    // Set up test return data to verify the completion handler is called properly
    NSData *returnData = [NSData data];
    NSURLResponse *returnResponse = [[NSURLResponse alloc] init];
    NSError *returnError = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];
    __block BOOL completionHandlerCalled = NO;

    // Actually perform the request
    [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        XCTAssertEqual(returnData, data);
        XCTAssertEqual(returnResponse, response);
        XCTAssertEqual(returnError, error);
        completionHandlerCalled = YES;
    }];

    // Verify the session was called
    [self.mockNSURLSession verify];

    // Call the captured completion handler with the return data
    completionHandler(returnData, returnResponse, returnError);
    XCTAssertTrue(completionHandlerCalled);
 }

- (void)testDataTaskRetry {
    // Create a test request
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.URL = [NSURL URLWithString:@"www.urbanairship.com"];
    }];

    // Expect a call to the NSURLSession and capture the callback
    __block UARequestCompletionHandler completionHandler = nil;
    [(NSURLSession *)[[self.mockNSURLSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        completionHandler = (__bridge UARequestCompletionHandler)arg;
    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURLRequest *urlRequest = (NSURLRequest *)obj;

        if (![urlRequest.HTTPMethod isEqualToString:request.method]) {
            return NO;
        }

        if (![urlRequest.URL isEqual:request.URL]) {
            return NO;
        }

        return YES;
    }] completionHandler:OCMOCK_ANY];


    __block BOOL retryBlockCalled = NO;

    // Actually perform the request
    [self.session dataTaskWithRequest:request
     retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
         retryBlockCalled = YES;
         return YES;
     } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
         XCTFail(@"Completion handler should not be called during retries");
     }];

    // Verify the session was called
    [self.mockNSURLSession verify];

    // Verify a delay was added for 30 seconds
    [[self.mockQueue expect] addOperation:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (![obj isKindOfClass:[UADelayOperation class]]) {
            return NO;
        }

        UADelayOperation *operation = (UADelayOperation *)obj;
        return operation.seconds == 30;
    }]];

    completionHandler(nil, nil, nil);

    [self.mockQueue verify];

    // Call the captured completion handler with the return data
    XCTAssertTrue(retryBlockCalled);
}

- (void)testCancel {
    [[self.mockQueue expect] cancelAllOperations];
    [self.session cancelAllRequests];

    [self.mockQueue verify];
}
@end
