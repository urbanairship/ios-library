/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAURLProtocol.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@interface UAURLProtocolTest : UABaseTest
@property (nonatomic, strong) NSURL *cachableURL;
@property (nonatomic, strong) NSURL *uncachableURL;

@property (nonatomic, strong) id client;
@property (nonatomic, strong) UAURLProtocol *urlProtocol;

@end

@implementation UAURLProtocolTest

- (void)setUp {
    [super setUp];

    self.cachableURL = [NSURL URLWithString:@"http://some-site.what"];
    self.uncachableURL = [NSURL URLWithString:@"http://some-other-site.what"];
    
    self.client = [self mockForProtocol:@protocol(NSURLProtocolClient)];
    self.urlProtocol = [[UAURLProtocol alloc] initWithRequest:[NSMutableURLRequest requestWithURL:self.cachableURL]
                                               cachedResponse:nil
                                                       client:self.client];


    [UAURLProtocol addCachableURL:self.cachableURL];
}

- (void)tearDown {
    [UAURLProtocol removeCachableURL:self.cachableURL];
    [UAURLProtocol clearCache];

    [self.client stopMocking];
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

#pragma GCC diagnostic pop

@end
