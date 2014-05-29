/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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
#import "UAOpenExternalURLAction.h"
#import <OCMock/OCMock.h>
#import "UAAction+Operators.h"
#import "UATestSynchronizer.h"

@interface UAOpenExternalURLActionTest : XCTestCase

@property (nonatomic, strong) UAActionArguments *emptyArgs;
@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) UATestSynchronizer *sync;
@property (nonatomic, strong) UAAction *action;
@property (nonatomic, strong) id mockApplication;

@end


@implementation UAOpenExternalURLActionTest



- (void)setUp {
    [super setUp];

    self.sync = [[UATestSynchronizer alloc] init];

    self.arguments = [[UAActionArguments alloc] init];
    self.action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [self.sync continue];
    }];
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
    self.arguments.value = @"http://some-valid-url";
    XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept valid string URLs");

    self.arguments.situation = UASituationManualInvocation;
    XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept any situations that is not UASituationBackgroundPush");

    self.arguments.value = [NSURL URLWithString:@"http://some-valid-url"];
    XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept NSURLs");

    self.arguments.value = nil;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should not accept a nil value");

    self.arguments.value = @3213;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should not accept an invalid url");

    self.arguments.value = @"oh hi";
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should not accept an invalid url");

    self.arguments.value = @"http://some-valid-url";
    self.arguments.situation = UASituationBackgroundPush;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should not accept arguments with UASituationBackgroundPush situation");
}

/**
 * Test perform with a string URL
 */
- (void)testPerformWithStringURL {
    __block UAActionResult *result;

    self.arguments.value = @"ftp://some-valid-url";
    self.arguments.situation = UASituationForegroundPush;

    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:self.arguments.value]];

    [self.action performWithArguments:self.arguments withCompletionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self.sync wait];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
    XCTAssertEqualObjects(result.value, self.arguments.value, @"results value should be the url");
    XCTAssertNil(result.error, @"result should have no error if the application successfully opens the url");
}


/**
 * Test perform with a NSURL
 */
- (void)testPerformWithNSURL {
    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"scheme://some-valid-url"];
    self.arguments.situation = UASituationForegroundPush;

    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:self.arguments.value];

    [self.action performWithArguments:self.arguments withCompletionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self.sync wait];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
    XCTAssertEqualObjects(result.value, ((NSURL *)self.arguments.value).absoluteString, @"results value should be the url");
    XCTAssertNil(result.error, @"result should have no error if the application successfully opens the url");
}

/**
 * Test perform when the application is unable to open the URL it returns an error
 */
- (void)testPerformError {
    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"scheme://some-valid-url"];
    self.arguments.situation = UASituationForegroundPush;

    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(NO)] openURL:OCMOCK_ANY];

    [self.action performWithArguments:self.arguments withCompletionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self.sync wait];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
    XCTAssertNotNil(result.error, @"result should have an error if the application failed to open the url");
    XCTAssertEqualObjects(UAOpenExternalURLActionErrorDomain, result.error.domain, @"error domain should be set to UAOpenExternalURLActionErrorDomain");
    XCTAssertEqual(UAOpenExternalURLActionErrorCodeURLFailedToOpen, result.error.code, @"error code should be set to UAOpenExternalURLActionErrorCodeURLFailedToOpen");
}

/**
 * Test normalizing phone URLs
 */
- (void)testPerformWithPhoneURL {
    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"sms://+1(541)555%2032195%202241%202313"];
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"sms:+15415553219522412313"]];

    [self.action performWithArguments:self.arguments withCompletionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self.sync wait];

    XCTAssertEqualObjects(result.value, @"sms:+15415553219522412313", @"results value should be normalized phone number");

    self.arguments.value = @"tel://+1541555adfasdfa%2032195%202241%202313";
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"tel:+15415553219522412313"]];

    [self.action performWithArguments:self.arguments withCompletionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self.sync wait];

    XCTAssertEqualObjects(result.value, @"tel:+15415553219522412313", @"results value should be normalized phone number");
}

/**
 * Test normalizing apple iTunes URLs
 */
- (void)testPerformWithiTunesURL {
    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"app://itunes.apple.com/some-app"];
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"http://itunes.apple.com/some-app"]];

    [self.action performWithArguments:self.arguments withCompletionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self.sync wait];

    XCTAssertEqualObjects(result.value, @"http://itunes.apple.com/some-app", @"results value should be http iTunes link");

    self.arguments.value = @"app://phobos.apple.com/some-app";
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"http://phobos.apple.com/some-app"]];

    [self.action performWithArguments:self.arguments withCompletionHandler:^(UAActionResult *performResult) {
        result = performResult;
    }];

    [self.sync wait];

    XCTAssertEqualObjects(result.value, @"http://phobos.apple.com/some-app", @"results value should be http iTunes link");
}
@end
