/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAActionArguments+Internal.h"
#import "UAirship+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAOpenExternalURLActionTest : UABaseTest

@property (nonatomic, strong) UAActionArguments *emptyArgs;
@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) UATestURLAllowList *URLAllowList;
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

    self.URLAllowList = [[UATestURLAllowList alloc] init];
    [[[self.mockAirship stub] andReturn:self.URLAllowList] URLAllowList];
}

/**
 * Test accepts valid arguments
 */
- (void)testAcceptsArguments {
    self.URLAllowList.isAllowedReturnValue = YES;

    UAOpenExternalURLAction *action = [[UAOpenExternalURLAction alloc] init];

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
    self.URLAllowList.isAllowedReturnValue = NO;

    UAOpenExternalURLAction *action = [[UAOpenExternalURLAction alloc] init];

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
    self.URLAllowList.isAllowedReturnValue = YES;

    XCTestExpectation *openURLExpectation = [self expectationWithDescription:@"openURL finished"];

    self.arguments.value = @"ftp://some-valid-url";
    self.arguments.situation = UASituationForegroundPush;

    UAOpenExternalURLAction *action = [[UAOpenExternalURLAction alloc] init];

    [[self.mockApplication expect] openURL:[NSURL URLWithString:self.arguments.value] options:@{} completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        BOOL (^handler)(BOOL) = obj;
        handler(YES);
        return YES;
    }]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertEqualObjects(performResult.value, self.arguments.value, @"results value should be the url");
        XCTAssertNil(performResult.error, @"result should have no error if the application successfully opens the url");
        [openURLExpectation fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
}

/**
 * Test perform with a NSURL
 */
- (void)testPerformWithNSURL {
    self.URLAllowList.isAllowedReturnValue = YES;

    XCTestExpectation *openURLExpectation = [self expectationWithDescription:@"openURL finished"];

    self.arguments.value = [NSURL URLWithString:@"scheme://some-valid-url"];
    self.arguments.situation = UASituationForegroundPush;

    UAOpenExternalURLAction *action = [[UAOpenExternalURLAction alloc] init];
    
    [[self.mockApplication expect] openURL:self.arguments.value options:@{} completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        BOOL (^handler)(BOOL) = obj;
        handler(YES);
        return YES;
    }]];

    [action performWithArguments:self.arguments completionHandler:^(UAActionResult *performResult) {
        XCTAssertEqualObjects(performResult.value, ((NSURL *)self.arguments.value).absoluteString, @"results value should be the url");
        XCTAssertNil(performResult.error, @"result should have no error if the application successfully opens the url");
        [openURLExpectation fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
}

/**
 * Test perform when the application is unable to open the URL it returns an error
 */
- (void)testPerformError {
    self.URLAllowList.isAllowedReturnValue = YES;

    XCTestExpectation *openURLExpectation = [self expectationWithDescription:@"openURL finished"];

    UAOpenExternalURLAction *action = [[UAOpenExternalURLAction alloc] init];

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
    }];

    [self waitForTestExpectations];

    XCTAssertNoThrow([self.mockApplication verify], @"application should try to open the url");
}


@end
