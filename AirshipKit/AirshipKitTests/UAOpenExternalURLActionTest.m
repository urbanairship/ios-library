/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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
#import "UAOpenExternalURLAction.h"
#import <OCMock/OCMock.h>
#import "UAAction+Operators.h"
#import "UAActionArguments+Internal.h"

@interface UAOpenExternalURLActionTest : XCTestCase

@property (nonatomic, strong) UAActionArguments *emptyArgs;
@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) id mockApplication;

@end


@implementation UAOpenExternalURLActionTest

- (void)setUp {
    [super setUp];

    self.arguments = [[UAActionArguments alloc] init];
    self.mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
}

- (void)tearDown {
    [self.mockApplication stopMocking];
    [super tearDown];
}

/**
* Test accepts valid arguments
*/
- (void)testAcceptsArguments {

    UAAction *action = [[UAOpenExternalURLAction alloc] init];

    self.arguments.value = @"http://some-valid-url";
    XCTAssertTrue([action acceptsArguments:self.arguments], @"action should accept valid string URLs");

    self.arguments.situation = UASituationManualInvocation;
    XCTAssertTrue([action acceptsArguments:self.arguments], @"action should accept any situations that is not UASituationBackgroundPush");

    self.arguments.value = [NSURL URLWithString:@"http://some-valid-url"];
    XCTAssertTrue([action acceptsArguments:self.arguments], @"action should accept NSURLs");

    self.arguments.value = nil;
    XCTAssertFalse([action acceptsArguments:self.arguments], @"action should not accept a nil value");

    self.arguments.value = @3213;
    XCTAssertFalse([action acceptsArguments:self.arguments], @"action should not accept an invalid url");

    self.arguments.value = @"oh hi";
    XCTAssertFalse([action acceptsArguments:self.arguments], @"action should not accept an invalid url");

    self.arguments.value = @"http://some-valid-url";
    self.arguments.situation = UASituationBackgroundPush;
    XCTAssertFalse([action acceptsArguments:self.arguments], @"action should not accept arguments with UASituationBackgroundPush situation");
}

/**
 * Test perform with a string URL
 */
- (void)testPerformWithStringURL {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    __block UAActionResult *result;

    self.arguments.value = @"ftp://some-valid-url";
    self.arguments.situation = UASituationForegroundPush;

    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:self.arguments.value]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run action with error %@.", error);
        }
    }];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
    XCTAssertEqualObjects(result.value, self.arguments.value, @"results value should be the url");
    XCTAssertNil(result.error, @"result should have no error if the application successfully opens the url");
}


/**
 * Test perform with a NSURL
 */
- (void)testPerformWithNSURL {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"scheme://some-valid-url"];
    self.arguments.situation = UASituationForegroundPush;

    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:self.arguments.value];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run action with error %@.", error);
        }
    }];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
    XCTAssertEqualObjects(result.value, ((NSURL *)self.arguments.value).absoluteString, @"results value should be the url");
    XCTAssertNil(result.error, @"result should have no error if the application successfully opens the url");
}

/**
 * Test perform when the application is unable to open the URL it returns an error
 */
- (void)testPerformError {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"scheme://some-valid-url"];
    self.arguments.situation = UASituationForegroundPush;

    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(NO)] openURL:OCMOCK_ANY];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run action with error %@.", error);
        }
    }];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
    XCTAssertNotNil(result.error, @"result should have an error if the application failed to open the url");
    XCTAssertEqualObjects(UAOpenExternalURLActionErrorDomain, result.error.domain, @"error domain should be set to UAOpenExternalURLActionErrorDomain");
    XCTAssertEqual(UAOpenExternalURLActionErrorCodeURLFailedToOpen, result.error.code, @"error code should be set to UAOpenExternalURLActionErrorCodeURLFailedToOpen");
}

/**
 * Test normalizing phone URLs
 */
- (void)testPerformWithPhoneURL {
    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"sms://+1(541)555%2032195%202241%202313"];
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"sms:+15415553219522412313"]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run action with error %@.", error);
        }
    }];


    XCTAssertEqualObjects(result.value, @"sms:+15415553219522412313", @"results value should be normalized phone number");

    testExpectation = [self expectationWithDescription:@"request finished"];

    action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    self.arguments.value = @"tel://+1541555adfasdfa%2032195%202241%202313";
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"tel:+15415553219522412313"]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run action with error %@.", error);
        }
    }];

    XCTAssertEqualObjects(result.value, @"tel:+15415553219522412313", @"results value should be normalized phone number");
}

/**
 * Test normalizing apple iTunes URLs
 */
- (void)testPerformWithiTunesURL {

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"app://itunes.apple.com/some-app"];
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"http://itunes.apple.com/some-app"]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run action with error %@.", error);
        }
    }];

    XCTAssertEqualObjects(result.value, @"http://itunes.apple.com/some-app", @"results value should be http iTunes link");

    testExpectation = [self expectationWithDescription:@"request finished"];

    action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    self.arguments.value = @"app://phobos.apple.com/some-app";
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"http://phobos.apple.com/some-app"]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to run action with error %@.", error);
        }
    }];

    XCTAssertEqualObjects(result.value, @"http://phobos.apple.com/some-app", @"results value should be http iTunes link");
}
@end
