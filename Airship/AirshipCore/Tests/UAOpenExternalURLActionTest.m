/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAOpenExternalURLAction.h"
#import "UAAction+Operators.h"
#import "UAActionArguments+Internal.h"
#import "UAURLAllowList.h"
#import "UAirship+Internal.h"
#import "UATestSystemVersion.h"

@interface UAOpenExternalURLActionTest : UABaseTest

@property (nonatomic, strong) UAActionArguments *emptyArgs;
@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, assign) id mockURLAllowList;
@property (nonatomic, assign) id mockAirship;

@end


@implementation UAOpenExternalURLActionTest

- (void)setUp {
    [super setUp];

    self.arguments = [[UAActionArguments alloc] init];
    self.mockApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];

    self.mockURLAllowList =  [self mockForClass:[UAURLAllowList class]];
    [[[self.mockAirship stub] andReturn:self.mockURLAllowList] URLAllowList];
}

- (void)tearDown {
    [self.mockApplication stopMocking];
    [self.mockURLAllowList stopMocking];
    [self.mockAirship stopMocking];
    [super tearDown];
}

/**
 * Test accepts valid arguments
 */
- (void)testAcceptsArguments {
    [[[[self.mockURLAllowList stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isAllowed:OCMOCK_ANY scope:UAURLAllowListScopeOpenURL];

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
 * Test rejects arguments with URLs that are not allowed.
 */
- (void)testURLAllowList {
    [[[[self.mockURLAllowList stub] andReturnValue:OCMOCK_VALUE(NO)] ignoringNonObjectArgs] isAllowed:OCMOCK_ANY scope:UAURLAllowListScopeOpenURL];

    UAAction *action = [[UAOpenExternalURLAction alloc] init];

    self.arguments.value = @"http://some-valid-url";
    XCTAssertFalse([action acceptsArguments:self.arguments]);

    self.arguments.situation = UASituationManualInvocation;
    XCTAssertFalse([action acceptsArguments:self.arguments]);

    self.arguments.value = [NSURL URLWithString:@"http://some-valid-url"];
    XCTAssertFalse([action acceptsArguments:self.arguments]);
}

/**
 * Test perform with a string URL
 */
- (void)testPerformWithStringURL {
    [[[[self.mockURLAllowList stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isAllowed:OCMOCK_ANY scope:UAURLAllowListScopeOpenURL];

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

    [self waitForTestExpectations];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
}

/**
 * Test perform with a NSURL
 */
- (void)testPerformWithNSURL {
    [[[[self.mockURLAllowList stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isAllowed:OCMOCK_ANY scope:UAURLAllowListScopeOpenURL];

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

    [self waitForTestExpectations];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
}

/**
 * Test perform when the application is unable to open the URL it returns an error
 */
- (void)testPerformError {
    [[[[self.mockURLAllowList stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isAllowed:OCMOCK_ANY scope:UAURLAllowListScopeOpenURL];

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

    [self waitForTestExpectations];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
}

/**
 * Test normalizing apple iTunes NSURL
 */
- (void)testPerformWithiTunesNSURL {
    [[[[self.mockURLAllowList stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isAllowed:OCMOCK_ANY scope:UAURLAllowListScopeOpenURL];

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

    [self waitForTestExpectations];
}

- (void)testParseURLFromArguments {
    // Arguments contain an invalid class
    self.arguments.value = [NSNumber numberWithBool:YES];
    NSURL *url = [UAOpenExternalURLAction parseURLFromArguments:self.arguments];
    XCTAssertNil(url);

    // Arguments contain a valid string
    self.arguments.value = @"http://google.com";
    url = [UAOpenExternalURLAction parseURLFromArguments:self.arguments];
    XCTAssertEqualObjects(url.absoluteString, self.arguments.value);

    // Arguments contain a valid URL
    self.arguments.value = [NSURL URLWithString:@"http://google.com"];
    url = [UAOpenExternalURLAction parseURLFromArguments:self.arguments];
    XCTAssertEqualObjects(url, self.arguments.value);
    
    // Arguments contain an apple itunes URL
    self.arguments.value = @"ims://phobos.apple.com";
    url = [UAOpenExternalURLAction parseURLFromArguments:self.arguments];
    XCTAssertEqualObjects(url.absoluteString, @"http://phobos.apple.com");
    
    // valid number
    self.arguments.value = @"sms:999-999-9999";
    url = [UAOpenExternalURLAction parseURLFromArguments:self.arguments];
    XCTAssertEqualObjects(url.absoluteString, self.arguments.value);

    // valid number
    self.arguments.value = @"sms:999%20999-9999";
    url = [UAOpenExternalURLAction parseURLFromArguments:self.arguments];
    XCTAssertEqualObjects(url.absoluteString, @"sms:999999-9999");

    // Valid percent encoding
    self.arguments.value = @"sms:%28999%29999-9999";
    url = [UAOpenExternalURLAction parseURLFromArguments:self.arguments];
    XCTAssertEqualObjects(url.absoluteString, @"sms:999999-9999");

    // invalid percent encoding
    self.arguments.value = @"sms:9999%95";
    url = [UAOpenExternalURLAction parseURLFromArguments:self.arguments];
    XCTAssertNil(url);
}

@end
