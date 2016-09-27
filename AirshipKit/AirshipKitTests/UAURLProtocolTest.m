/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import "UAURLProtocol.h"
#import "UAHTTPRequest+Internal.h"

#import "UAHTTPConnection+Internal.h"

@interface UAURLProtocolTest : XCTestCase
@property (nonatomic, strong) NSURL *cachableURL;
@property (nonatomic, strong) NSURL *uncachableURL;

@property (nonatomic, strong) id client;
@property (nonatomic, strong) UAURLProtocol *urlProtocol;

@property (nonatomic, strong) id connection;

@property (nonatomic, strong) UAHTTPConnectionSuccessBlock connectionSuccessBlock;
@property (nonatomic, strong) UAHTTPConnectionFailureBlock connectionFailureBlock;
@property (nonatomic, strong) UAHTTPRequest *connectionRequest;

@end

@implementation UAURLProtocolTest

- (void)setUp {
    [super setUp];

    self.cachableURL = [NSURL URLWithString:@"http://some-site.what"];
    self.uncachableURL = [NSURL URLWithString:@"http://some-other-site.what"];
    
    self.client = [OCMockObject niceMockForProtocol:@protocol(NSURLProtocolClient)];
    self.urlProtocol = [[UAURLProtocol alloc] initWithRequest:[NSMutableURLRequest requestWithURL:self.cachableURL]
                                               cachedResponse:nil
                                                       client:self.client];



    self.connection = [OCMockObject mockForClass:[UAHTTPConnection class]];


    // Stub the connection connectionWithRequest:successBlock:failureBlock:
    [[[self.connection stub] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        self.connectionRequest = (__bridge UAHTTPRequest *)arg;

        [invocation getArgument:&arg atIndex:3];
        self.connectionSuccessBlock = (__bridge UAHTTPConnectionSuccessBlock)arg;

        [invocation getArgument:&arg atIndex:4];
        self.connectionFailureBlock = (__bridge UAHTTPConnectionFailureBlock)arg;

        [invocation setReturnValue: &_connection];
    }] connectionWithRequest:OCMOCK_ANY
                successBlock:OCMOCK_ANY
                failureBlock:OCMOCK_ANY];


    [UAURLProtocol addCachableURL:self.cachableURL];
}

- (void)tearDown {
    [UAURLProtocol removeCachableURL:self.cachableURL];
    [UAURLProtocol clearCache];

    [self.client stopMocking];
    [self.connection stopMocking];
    self.connectionSuccessBlock = nil;
    self.connectionFailureBlock = nil;
    self.connectionRequest = nil;

    [super tearDown];
}

/*
 * Test that protocol responds to 
 * requests for URLs that have been 
 * registered, do not contain the skip header,
 * and are HTTP method 'GET'.
 */
- (void)testCanInitWithRequest {
    NSURLRequest *request = [NSURLRequest requestWithURL:self.cachableURL];
    XCTAssertTrue([UAURLProtocol canInitWithRequest:request], @"UAURLProtocol should be able to init with a cachable url request.");
}

/*
 * Test that the protocol does not respond
 * to requests with URL's that have not been
 * registered.
 */
- (void)testCanInitWithRequestUnknownURL {
    NSURLRequest *request = [NSURLRequest requestWithURL:self.uncachableURL];

    XCTAssertFalse([UAURLProtocol canInitWithRequest:request], @"UAURLProtocol should ignore requests whose url or mainDocumentURl is not added as cachable URL.");
}

/*
 * Test that the protocol does not respond
 * to requests where the URL scheme is not 'http' or 'https'
 */
- (void)testCanInitWithRequestNonHttp {

    NSURL *nonHttp = [NSURL URLWithString:@"data:image/gif;base64,ABCDEFGHIJKLMNOP"];
    NSURLRequest *request = [NSURLRequest requestWithURL:nonHttp];

    XCTAssertFalse([UAURLProtocol canInitWithRequest:request], @"UAURLProtocol should not init when the URL scheme is not 'http' or 'https' request.");
}

/*
 * Test that protocol responds to
 * requests that have a registered mainDocumentURL,
 * do not contain the skip header,
 * and are HTTP method 'GET'.
 */
- (void)testCanInitWithRequestMainDocumentURL {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.uncachableURL];
    request.mainDocumentURL = self.cachableURL;

    XCTAssertTrue([UAURLProtocol canInitWithRequest:request], @"UAURLProtocol should be able to init with a request with a mainDocumentURL that is cachable.");
}

/*
 * Test that the protocol does not respond
 * to requests with the UA_SKIP_PROTOCOL_HEADER
 * header.
 */
- (void)testCanInitWithRequestSkipHeader {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.cachableURL];
    [request setValue:@"" forHTTPHeaderField:kUASkipProtocolHeader];


    XCTAssertFalse([UAURLProtocol canInitWithRequest:request], @"UAURLProtocol should ignore requests with UA_SKIP_PROTOCOL_HEADER header.");
}

/*
 * Test that the protocol does not respond
 * to requests with the other HTTP methods
 */
- (void)testCanInitWithRequesOtherHTTPMethods {

    NSArray *ignoredHTTPMethods = @[@"POST", @"PUT", @"DELETE", @"HEAD", @"OPTIONS", @"TRACE", @"CONNECT"];

    for (NSString *httpMethod in ignoredHTTPMethods) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.cachableURL];
        request.HTTPMethod = httpMethod;

        XCTAssertFalse([UAURLProtocol canInitWithRequest:request], @"UAURLProtocol should ignore requests with http method %@.", httpMethod);
    }
}

/*
 * Test that the protocol only includes
 * If-Modified-Since header if its a new request.
 */
- (void)testStartLoadingRequestHeaders {
    NSData *data = [@"SomeData" dataUsingEncoding:NSUTF8StringEncoding];

    __block UAHTTPRequest *request = [self createResponseRequestWithUrl:self.urlProtocol.request.URL
                                                             statusCode:200
                                                                headers:@{@"Date": @"Sunday, 06-Nov-94 08:49:37 GMT"}
                                                                   data:data];

    [(UAHTTPConnection *)[[self.connection stub] andDo:^(NSInvocation *invocation) {
        BOOL ret = YES;
        [invocation setReturnValue:&ret];
        self.connectionSuccessBlock(request);
    }] start];

    [self.urlProtocol startLoading];

    XCTAssertNotNil([self.connectionRequest.headers valueForKey:kUASkipProtocolHeader], @"Requests should contain the skip protocol header.");
    XCTAssertNil([self.connectionRequest.headers valueForKey:@"If-Modified-Since"], @"Uncached request should not contain if modified since time.");


    // Load the request again, the headers should have a modified since time
    [self.urlProtocol startLoading];
    XCTAssertEqualObjects(@"Sunday, 06-Nov-94 08:49:37 GMT", [self.connectionRequest.headers valueForKey:@"If-Modified-Since"],
                          @"Previously cached request should contain if modified since time header.");

}

/*
 * Test that the protocol returns the cached
 * response if the response status is not 200 and
 * it has a cached response.
 */
- (void)testStartLoadingCachedRequest {

    NSData *data = [@"SomeData" dataUsingEncoding:NSUTF8StringEncoding];

    UAHTTPRequest *successRequest = [self createResponseRequestWithUrl:self.urlProtocol.request.URL
                                                                    statusCode:200
                                                                       headers:@{@"Date": @"Sunday, 06-Nov-94 08:49:37 GMT",
                                                                                @"SomeOtherKey": @"SomeOtherValue"}
                                                                          data:data];


    UAHTTPRequest *failedRequest = [self createResponseRequestWithUrl:self.urlProtocol.request.URL
                                                           statusCode:404
                                                              headers:@{@"Date": @"Sunday, 06-Nov-94 08:49:37 GMT"}
                                                                  data:nil];

    __block UAHTTPRequest *request = nil;

    [(UAHTTPConnection *)[[self.connection stub] andDo:^(NSInvocation *invocation) {
        BOOL ret = YES;
        [invocation setReturnValue:&ret];
        self.connectionSuccessBlock(request);
    }] start];

    // Seed the cache with succcess request
    request = successRequest;
    [self.urlProtocol startLoading];

    // Change to failed request
    request = failedRequest;

    // Expect success request from the cache
    [[self.client expect] URLProtocol:self.urlProtocol didReceiveResponse:[OCMArg checkWithBlock:^BOOL(id value){
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)value;

        return [response.allHeaderFields isEqualToDictionary:successRequest.response.allHeaderFields]
                && response.statusCode == successRequest.response.statusCode;

    }] cacheStoragePolicy:NSURLCacheStorageNotAllowed];


    [[self.client expect] URLProtocol:self.urlProtocol didLoadData:[OCMArg checkWithBlock:^BOOL(id value){
        return [value isEqualToData:data];
    }]];

    [[self.client expect] URLProtocolDidFinishLoading:self.urlProtocol];

    [self.urlProtocol startLoading];

    XCTAssertNoThrow([self.client verify], @"Client should of received information from the cache, not the failed request");
}

/*
 * Test that the protocol returns cached
 * responses when the connection has an error and 
 * it has a cached response.
 */
- (void)testStartLoadingCachedRequestOnError{
    NSData *data = [@"SomeData" dataUsingEncoding:NSUTF8StringEncoding];

     __block UAHTTPRequest *request = [self createResponseRequestWithUrl:self.urlProtocol.request.URL
                                                            statusCode:200
                                                               headers:@{@"Date": @"Sunday, 06-Nov-94 08:49:37 GMT",
                                                                         @"SomeOtherKey": @"SomeOtherValue"}
                                                                  data:data];

    [(UAHTTPConnection *)[[self.connection stub] andDo:^(NSInvocation *invocation) {
        BOOL ret = YES;
        [invocation setReturnValue:&ret];
        self.connectionSuccessBlock(request);
    }] start];

    // Seed the cache with succcess request
    [self.urlProtocol startLoading];

    // Change to error completion block
    [(UAHTTPConnection *)[[self.connection stub] andDo:^(NSInvocation *invocation) {
        BOOL ret = YES;
        [invocation setReturnValue:&ret];
        self.connectionFailureBlock(request);
    }] start];


    [[self.client expect] URLProtocol:self.urlProtocol didReceiveResponse:[OCMArg checkWithBlock:^BOOL(id value){
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)value;

        return [response.allHeaderFields isEqualToDictionary:request.response.allHeaderFields]
        && response.statusCode == request.response.statusCode;

    }] cacheStoragePolicy:NSURLCacheStorageNotAllowed];


    [[self.client expect] URLProtocol:self.urlProtocol didLoadData:[OCMArg checkWithBlock:^BOOL(id value){
        return [value isEqualToData:data];
    }]];

    [[self.client expect] URLProtocolDidFinishLoading:self.urlProtocol];

    [self.urlProtocol startLoading];

    XCTAssertNoThrow([self.client verify], @"Client should of received information from the cache on error.");
}

/*
 * Test that the protocol returns the failed
 * response when no cached response is
 * available
 */
- (void)testStartLoadingNoCachedRequest {
    NSData *data = [@"SomeData" dataUsingEncoding:NSUTF8StringEncoding];

    __block UAHTTPRequest *request = [self createResponseRequestWithUrl:self.urlProtocol.request.URL
                                                             statusCode:500
                                                                headers:@{@"Date": @"Sunday, 06-Nov-94 08:49:37 GMT",
                                                                          @"SomeOtherKey": @"SomeOtherValue"}
                                                                   data:data];

    [(UAHTTPConnection *)[[self.connection stub] andDo:^(NSInvocation *invocation) {
        BOOL ret = YES;
        [invocation setReturnValue:&ret];
        self.connectionSuccessBlock(request);
    }] start];


    [[self.client expect] URLProtocol:self.urlProtocol didReceiveResponse:[OCMArg checkWithBlock:^BOOL(id value){
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)value;

        return [response.allHeaderFields isEqualToDictionary:request.response.allHeaderFields]
        && response.statusCode == request.response.statusCode;

    }] cacheStoragePolicy:NSURLCacheStorageNotAllowed];


    [[self.client expect] URLProtocol:self.urlProtocol didLoadData:[OCMArg checkWithBlock:^BOOL(id value){
        return [value isEqualToData:data];
    }]];

    [[self.client expect] URLProtocolDidFinishLoading:self.urlProtocol];

    [self.urlProtocol startLoading];

    XCTAssertNoThrow([self.client verify], @"Client should of receive failed request when no cache to fallback on.");
}

/*
 * Test that the protocol returns an error
 * if the connection has an error and
 * there is no cached response.
 */
- (void)testStartLoadingNoCachedRequestOnError {
    __block UAHTTPRequest *request = [self createResponseRequestWithUrl:self.urlProtocol.request.URL
                                                             statusCode:500
                                                                headers:@{@"Date": @"Sunday, 06-Nov-94 08:49:37 GMT",
                                                                          @"SomeOtherKey": @"SomeOtherValue"}
                                                                   data:nil];

    // Failure block for error
    [(UAHTTPConnection *)[[self.connection stub] andDo:^(NSInvocation *invocation) {
        self.connectionFailureBlock(request);

        BOOL ret = YES;
        [invocation setReturnValue:&ret];
    }] start];


    [[self.client reject] URLProtocol:self.urlProtocol didReceiveResponse:OCMOCK_ANY cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [[self.client reject] URLProtocol:self.urlProtocol didLoadData:OCMOCK_ANY];

    [[self.client expect] URLProtocol:self.urlProtocol didFailWithError:OCMOCK_ANY];


    [self.urlProtocol startLoading];

    XCTAssertNoThrow([self.client verify], @"Client should of receive error request when no cache to fallback on.");
}



- (UAHTTPRequest *)createResponseRequestWithUrl:(NSURL *)URL
                               statusCode:(NSInteger)statusCode
                                  headers:(NSDictionary *)headers
                                     data:(NSData *)data {

    UAHTTPRequest *request = [[UAHTTPRequest alloc] init];
    request.response = [[NSHTTPURLResponse alloc] initWithURL:URL
                                                   statusCode:statusCode
                                                  HTTPVersion:@"HTTP/1.1"
                                                 headerFields:headers];
    request.responseData = data;

    return request;
}




@end
