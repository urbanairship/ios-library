/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAURLProtocol.h"

@interface UAURLProtocolTest : XCTestCase
@property (nonatomic, strong) NSURL *cachableURL;
@property (nonatomic, strong) NSURL *uncachableURL;

@end

@implementation UAURLProtocolTest

- (void)setUp {
    [super setUp];

    self.cachableURL = [NSURL URLWithString:@"http://some-site.what"];
    self.uncachableURL = [NSURL URLWithString:@"http://some-other-site.what"];
    [UAURLProtocol addCachableURL:self.cachableURL];
}

- (void)tearDown {
    [UAURLProtocol removeCachableURL:self.cachableURL];

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

    XCTAssertFalse([UAURLProtocol canInitWithRequest:request], @"UAURLProtocol should ignore requests whos url or mainDocumentURl is not added as cachable URL.");
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
- (void)tesCanInitWithRequestSkipHeader {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.cachableURL];
    [request setValue:@"" forHTTPHeaderField:UA_SKIP_PROTOCOL_HEADER];


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
 Caching tests:
     make request, make sure new request is received
     make same request, slightly different headers, make sure old request headers is received
     return error, make sure old request is recevied
     reeturn !200, make sure old request is received
 */

@end
