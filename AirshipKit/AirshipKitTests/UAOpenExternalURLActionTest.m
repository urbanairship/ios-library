/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAOpenExternalURLAction.h"
#import <OCMock/OCMock.h>
#import "UAAction+Operators.h"
#import "UAActionArguments+Internal.h"

@interface UAOpenExternalURLActionTest : UABaseTest

@property (nonatomic, strong) UAActionArguments *emptyArgs;
@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockProcessInfo;
@property (nonatomic, assign) int testOSMajorVersion;

@end


@implementation UAOpenExternalURLActionTest

- (void)setUp {
    [super setUp];

    // Set default OS major version to 10 by default
    self.testOSMajorVersion = 10;
    self.mockProcessInfo = [self mockForClass:[NSProcessInfo class]];
    [[[self.mockProcessInfo stub] andReturn:self.mockProcessInfo] processInfo];
    [[[[self.mockProcessInfo stub] andDo:^(NSInvocation *invocation) {
        NSOperatingSystemVersion arg;
        [invocation getArgument:&arg atIndex:2];

        BOOL result = self.testOSMajorVersion >= arg.majorVersion;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){0, 0, 0}];

    self.arguments = [[UAActionArguments alloc] init];
    self.mockApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];
}

- (void)tearDown {
    [self.mockApplication stopMocking];
    [self.mockProcessInfo stopMocking];
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
    XCTestExpectation *openURLExpectation = [self expectationWithDescription:@"openURL finished"];

    self.arguments.value = @"ftp://some-valid-url";
    self.arguments.situation = UASituationForegroundPush;

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [openURLExpectation fulfill];
    }];

    [[self.mockApplication expect] openURL:[NSURL URLWithString:self.arguments.value] options:@{} completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        BOOL (^handler)(BOOL) = obj;
        handler(YES);
        return YES;
    }]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertEqualObjects(performResult.value, self.arguments.value, @"results value should be the url");
        XCTAssertNil(performResult.error, @"result should have no error if the application successfully opens the url");
    }];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to open URL with error %@.", error);
        }
    }];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
}

/**
 * Test perform with a string URL on iOS 9
 */
- (void)testPerformWithStringURLiOS9 {
    self.testOSMajorVersion = 9;

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    __block UAActionResult *result;

    self.arguments.value = @"ftp://some-valid-url";
    self.arguments.situation = UASituationForegroundPush;

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:self.arguments.value]];
#pragma GCC diagnostic pop

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

    XCTestExpectation *openURLExpectation = [self expectationWithDescription:@"openURL finished"];

    self.arguments.value = [NSURL URLWithString:@"scheme://some-valid-url"];
    self.arguments.situation = UASituationForegroundPush;

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [openURLExpectation fulfill];
    }];

    [[self.mockApplication expect] openURL:self.arguments.value options:@{} completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        BOOL (^handler)(BOOL) = obj;
        handler(YES);
        return YES;
    }]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertEqualObjects(performResult.value, ((NSURL *)self.arguments.value).absoluteString, @"results value should be the url");
        XCTAssertNil(performResult.error, @"result should have no error if the application successfully opens the url");
    }];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to open URL with error %@.", error);
        }
    }];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
}

/**
 * Test perform with a NSURL iOS 9
 */
- (void)testPerformWithNSURLiOS9 {
    self.testOSMajorVersion = 9;

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"scheme://some-valid-url"];
    self.arguments.situation = UASituationForegroundPush;

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:self.arguments.value];
#pragma GCC diagnostic pop


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
    XCTestExpectation *openURLExpectation = [self expectationWithDescription:@"openURL finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
    }];

    self.arguments.value = [NSURL URLWithString:@"scheme://some-valid-url"];
    self.arguments.situation = UASituationForegroundPush;

    [[self.mockApplication expect] openURL:self.arguments.value options:@{} completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        BOOL (^handler)(BOOL) = obj;
        handler(NO);
        [openURLExpectation fulfill];
        return YES;
    }]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertNotNil(performResult.error, @"result should have an error if the application failed to open the url");
        XCTAssertEqualObjects(UAOpenExternalURLActionErrorDomain, performResult.error.domain, @"error domain should be set to UAOpenExternalURLActionErrorDomain");
        XCTAssertEqual(UAOpenExternalURLActionErrorCodeURLFailedToOpen, performResult.error.code, @"error code should be set to UAOpenExternalURLActionErrorCodeURLFailedToOpen");
    }];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to open URL with error %@.", error);
        }
    }];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
}

/**
 * Test perform when the application is unable to open the URL it returns an error iOS 9
 */
- (void)testPerformErroriOS9 {
    self.testOSMajorVersion = 9;

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"scheme://some-valid-url"];
    self.arguments.situation = UASituationForegroundPush;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(NO)] openURL:OCMOCK_ANY];
#pragma GCC diagnostic pop

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
 * Test normalizing apple iTunes NSURL
 */
- (void)testPerformWithiTunesNSURL {
    XCTestExpectation *openURLExpectation = [self expectationWithDescription:@"openURL finished"];

    self.arguments.value = [NSURL URLWithString:@"http://itunes.apple.com/some-app"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [openURLExpectation fulfill];
    }];

    [[self.mockApplication expect] openURL:self.arguments.value options:@{} completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        BOOL (^handler)(BOOL) = obj;
        handler(YES);
        return YES;
    }]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertEqualObjects(performResult.value, [self.arguments.value absoluteString]);
        XCTAssertEqualObjects(performResult.value, @"http://itunes.apple.com/some-app", @"results value should be http iTunes link");
    }];

    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Failed to open URL with error %@.", error);
        }
    }];
}

/**
 * Test normalizing apple iTunes URLs iOS9
 */
- (void)testPerformWithiTunesURL {
    self.testOSMajorVersion = 9;

    XCTestExpectation *testExpectation = [self expectationWithDescription:@"request finished"];

    UAAction *action = [[[UAOpenExternalURLAction alloc] init] postExecution:^(UAActionArguments *args, UAActionResult *result){
        [testExpectation fulfill];
    }];

    __block UAActionResult *result;

    self.arguments.value = [NSURL URLWithString:@"app://itunes.apple.com/some-app"];

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"http://itunes.apple.com/some-app"]];
#pragma GCC diagnostic pop

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

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [[[self.mockApplication expect] andReturnValue:OCMOCK_VALUE(YES)] openURL:[NSURL URLWithString:@"http://phobos.apple.com/some-app"]];
#pragma GCC diagnostic pop

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
