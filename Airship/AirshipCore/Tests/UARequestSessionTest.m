/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARequestSession.h"
#import "UAirship+Internal.h"

@interface UARequestSessionTest : UAAirshipBaseTest
@property (nonatomic, strong) id mockNSURLSession;
@property (nonatomic, strong) UARequestSession *session;
@end

typedef void (^NSURLResponseCallback)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

@implementation UARequestSessionTest

- (void)setUp {
    [super setUp];
    self.mockNSURLSession = [self mockForClass:[NSURLSession class]];
    self.session = [UARequestSession sessionWithConfig:self.config
                                          NSURLSession:self.mockNSURLSession];
}

- (void)testPerformHTTPRequest {
     // Create a test request
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
        builder.URL = [NSURL URLWithString:@"https://www.urbanairship.com"];
        builder.username = @"name";
        builder.password = @"password";
        [builder setValue:@"header_value" forHeader:@"header_key"];
    }];

    // Expect a call to the NSURLSession and capture the callback
    __block UAHTTPRequestCompletionHandler completionHandler;
    [(NSURLSession *)[[self.mockNSURLSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
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
    NSHTTPURLResponse *returnResponse = [[NSHTTPURLResponse alloc] init];
    __block BOOL completionHandlerCalled = NO;

    // Actually perform the request
    [self.session performHTTPRequest:request completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        XCTAssertEqual(returnData, data);
        XCTAssertEqual(returnResponse, response);
        XCTAssertNil(error);
        completionHandlerCalled = YES;
    }];

    // Verify the session was called
    [self.mockNSURLSession verify];

    // Call the captured completion handler with the return data
    completionHandler(returnData, returnResponse, nil);
    XCTAssertTrue(completionHandlerCalled);
 }

- (void)testDefaultHeaders {

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.URL = [NSURL URLWithString:@"https://www.urbanairship.com"];
    }];

    // Expect a call to the NSURLSession and capture the callback
    [(NSURLSession *)[self.mockNSURLSession expect]  dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURLRequest *urlRequest = (NSURLRequest *)obj;
        NSString *expectedUserAgent = [NSString stringWithFormat:@"(UALib %@; %@)", [UAirshipVersion get], self.config.appKey];
        XCTAssertEqualObjects(expectedUserAgent, urlRequest.allHTTPHeaderFields[@"User-Agent"]);

        XCTAssertEqualObjects(self.config.appKey, urlRequest.allHTTPHeaderFields[@"X-UA-App-Key"]);

        return YES;
    }] completionHandler:OCMOCK_ANY];

    [self.session performHTTPRequest:request completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {}];

    // Verify the session was called
    [self.mockNSURLSession verify];
}

- (void)testCancel {
    // Create a test request
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.body = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
        builder.URL = [NSURL URLWithString:@"https://www.urbanairship.com"];
    }];

    id mockTask = [self mockForClass:[NSURLSessionTask class]];
    [[mockTask expect] cancel];

    [[[self.mockNSURLSession expect] andReturn:mockTask] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Actually perform the request
    UADisposable *disposable = [self.session performHTTPRequest:request completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {}];

    [disposable dispose];

    [self.mockNSURLSession verify];
    [mockTask verify];
}


- (void)testPerformHTTPRequestError {
    // Create a test request
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.URL = [NSURL URLWithString:@"https://www.urbanairship.com"];
    }];

    // Expect a call to the NSURLSession and capture the callback
    __block NSURLResponseCallback completionHandler;
    [(NSURLSession *)[[self.mockNSURLSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        completionHandler = (__bridge NSURLResponseCallback)arg;
    }] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Set up test return data to verify the completion handler is called properly
    NSData *returnData = [NSData data];
    NSHTTPURLResponse *returnResponse = [[NSHTTPURLResponse alloc] init];
    NSError *returnError = [NSError errorWithDomain:@"domain" code:100 userInfo:nil];
    __block BOOL completionHandlerCalled = NO;

    // Actually perform the request
    [self.session performHTTPRequest:request completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        XCTAssertNil(data);
        XCTAssertNil(response);
        XCTAssertEqual(returnError, error);
        completionHandlerCalled = YES;
    }];

    // Verify the session was called
    [self.mockNSURLSession verify];

    // Call the captured completion handler with the return data
    completionHandler(returnData, returnResponse, returnError);
    XCTAssertTrue(completionHandlerCalled);
}

- (void)testPerformHTTPRequestErrorInvalidResponse {
    // Create a test request
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.method = @"POST";
        builder.URL = [NSURL URLWithString:@"https://www.urbanairship.com"];
    }];

    // Expect a call to the NSURLSession and capture the callback
    __block NSURLResponseCallback completionHandler;
    [(NSURLSession *)[[self.mockNSURLSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        completionHandler = (__bridge NSURLResponseCallback)arg;
    }] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // Set up test return data to verify the completion handler is called properly
    NSURLResponse *urlResponse = [[NSURLResponse alloc] init];
    __block BOOL completionHandlerCalled = NO;

    // Actually perform the request
    [self.session performHTTPRequest:request completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        XCTAssertNil(data);
        XCTAssertNil(response);
        XCTAssertEqual(UARequestSessionErrorDomain, error.domain);
        XCTAssertEqual(UARequestSessionErrorInvalidHTTPResponse, error.code);
        completionHandlerCalled = YES;
    }];

    // Verify the session was called
    [self.mockNSURLSession verify];

    // Call the captured completion handler with the return data
    completionHandler(nil, urlResponse, nil);
    XCTAssertTrue(completionHandlerCalled);
}

@end
