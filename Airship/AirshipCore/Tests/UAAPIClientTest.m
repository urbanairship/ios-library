/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAAPIClient.h"
#import "UARuntimeConfig.h"

@interface UAAPIClientTest : UAAirshipBaseTest
@property(nonatomic, strong) UAAPIClient *client;
@property(nonatomic, strong) id mockSession;
@end

@implementation UAAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [[UAAPIClient alloc] initWithConfig:self.config session:self.mockSession];
}

- (void)testCancel {
    [[self.mockSession expect] cancelAllRequests];
    [self.client cancelAllRequests];

    [self.mockSession verify];
}

- (void)testCastResponse {
    NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://cool.story"] statusCode:200 HTTPVersion:@"1.1" headerFields:@{}];

    NSError *error;

    NSHTTPURLResponse *cast = [self.client castResponse:response error:&error];
    XCTAssertTrue([cast isKindOfClass:[NSHTTPURLResponse class]]);
    XCTAssertNil(error);
}

- (void)testCastResponseInvalidType {
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[NSURL URLWithString:@"ftp://no.good"] MIMEType:@"image/gif" expectedContentLength:2000 textEncodingName:nil];

    NSError *error;

    NSHTTPURLResponse *cast = [self.client castResponse:response error:&error];

    XCTAssertFalse([cast isKindOfClass:[NSHTTPURLResponse class]]);
    XCTAssertEqualObjects(error.domain, UAAPIClientErrorDomain);
    XCTAssertEqual(error.code, UAAPIClientErrorInvalidURLResponse);
}

- (void)testCastResponseExistingError {
    NSURLResponse *response;

    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:12345 userInfo:@{}];

    NSHTTPURLResponse *cast = [self.client castResponse:response error:&error];

    XCTAssertFalse([cast isKindOfClass:[NSHTTPURLResponse class]]);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(error.code, 12345);
}

@end
