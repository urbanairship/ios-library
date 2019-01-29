/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UALandingPageAction.h"
#import "UAURLProtocol.h"
#import "UAOverlayViewController.h"
#import "UAAction+Internal.h"
#import "UAirship+Internal.h"
#import "UAConfig.h"
#import "UAUtils+Internal.h"
#import "NSString+UAURLEncoding.h"

@interface UALandingPageActionTest : UABaseTest

@property (nonatomic, strong) id mockOverlayViewController;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockConfig;
@property (nonatomic, strong) UALandingPageAction *action;
@property (nonatomic, assign) id mockWhitelist;


@end

@implementation UALandingPageActionTest

- (void)setUp {
    [super setUp];
    self.action = [[UALandingPageAction alloc] init];
    self.mockOverlayViewController = [self mockForClass:[UAOverlayViewController class]];

    self.mockConfig = [self mockForClass:[UAConfig class]];
    self.mockAirship = [self mockForClass:[UAirship class]];
    self.mockWhitelist =  [self mockForClass:[UAWhitelist class]];

    [[[self.mockAirship stub] andReturn:self.mockConfig] config];
    [[[self.mockAirship stub] andReturn:self.mockWhitelist] whitelist];
    [UAirship setSharedAirship:self.mockAirship];

    [[[self.mockConfig stub] andReturn:@"app-key"] appKey];
    [[[self.mockConfig stub] andReturn:kUAProductionLandingPageContentURL] landingPageContentURL];
    [[[self.mockConfig stub] andReturn:@"app-secret"] appSecret];
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [[[self.mockConfig stub] andReturnValue:OCMOCK_VALUE((NSUInteger)100)] cacheDiskSizeInMB];
#pragma GCC diagnostic pop
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockWhitelist stopMocking];
    [self.mockConfig stopMocking];
    [self.mockOverlayViewController stopMocking];
}

/**
 * Test accepts arguments
 */
- (void)testAcceptsArguments {
    [[[[self.mockWhitelist stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isWhitelisted:OCMOCK_ANY scope:UAWhitelistScopeOpenURL];

    [self verifyAcceptsArgumentsWithValue:@"foo.urbanairship.com" shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@"https://foo.urbanairship.com" shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@"http://foo.urbanairship.com" shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@"file://foo.urbanairship.com" shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:[NSURL URLWithString:@"https://foo.urbanairship.com"] shouldAccept:YES];

    // Verify UA content ID urls
    [self verifyAcceptsArgumentsWithValue:@"u:content-id" shouldAccept:true];
}

/**
 * Test accepts arguments rejects argument values that are unable to parsed
 * as a URL
 */
- (void)testAcceptsArgumentsNo {
    [[[[self.mockWhitelist stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isWhitelisted:OCMOCK_ANY scope:UAWhitelistScopeOpenURL];

    [self verifyAcceptsArgumentsWithValue:nil shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:[[NSObject alloc] init] shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@[] shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@"u:" shouldAccept:NO];
}

/**
 * Test rejects arguments with URLs that are not whitelisted.
 */
- (void)testWhiteList {
    [[[[self.mockWhitelist stub] andReturnValue:OCMOCK_VALUE(NO)] ignoringNonObjectArgs] isWhitelisted:OCMOCK_ANY scope:UAWhitelistScopeOpenURL];

    [self verifyAcceptsArgumentsWithValue:@"foo.urbanairship.com" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@"https://foo.urbanairship.com" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@"http://foo.urbanairship.com" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@"file://foo.urbanairship.com" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:[NSURL URLWithString:@"https://foo.urbanairship.com"] shouldAccept:NO];
}

/**
 * Test perform in UASituationBackgroundPush
 */
- (void)testPerformInForeground {
    [[[[self.mockWhitelist stub] andReturnValue:OCMOCK_VALUE(YES)] ignoringNonObjectArgs] isWhitelisted:OCMOCK_ANY scope:UAWhitelistScopeOpenURL];

    // Verify https is added to schemeless urls
    [self verifyPerformInForegroundWithValue:@"foo.urbanairship.com" expectedUrl:@"https://foo.urbanairship.com"];

    // Verify common scheme types
    [self verifyPerformInForegroundWithValue:@"http://foo.urbanairship.com" expectedUrl:@"http://foo.urbanairship.com"];
    [self verifyPerformInForegroundWithValue:@"https://foo.urbanairship.com" expectedUrl:@"https://foo.urbanairship.com"];
    [self verifyPerformInForegroundWithValue:[NSURL URLWithString:@"https://foo.urbanairship.com"] expectedUrl:@"https://foo.urbanairship.com"];
    [self verifyPerformInForegroundWithValue:@"file://foo.urbanairship.com" expectedUrl:@"file://foo.urbanairship.com"];

    // Verify content urls - https://dl.urbanairship.com/<app>/<id>
    // u:<id> where id is ascii85 encoded... so it needs to be url encoded
    [self verifyPerformInForegroundWithValue:@"u:<~@rH7,ASuTABk.~>"
                                 expectedUrl:@"https://dl.urbanairship.com/aaa/app-key/%3C~%40rH7,ASuTABk.~%3E"
                             expectedHeaders:@{@"Authorization": [UAUtils appAuthHeaderString]}];
}


/**
 * Helper method to verify perform in foreground situations
 */
- (void)commonVerifyPerformInForegroundWithValue:(id)value expectedUrl:(NSString *)expectedUrl expectedHeaders:(NSDictionary *)headers mockedViewController:(id)mockedViewController {
    NSArray *situations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                            [NSNumber numberWithInteger:UASituationForegroundPush],
                            [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                            [NSNumber numberWithInteger:UASituationManualInvocation],
                            [NSNumber numberWithInteger:UASituationAutomation]];
    
    for (NSNumber *situationNumber in situations) {
        [[[mockedViewController expect] ignoringNonObjectArgs] showURL:[OCMArg checkWithBlock:^(id obj) {
            return (BOOL)([obj isKindOfClass:[NSURL class]] && [((NSURL *)obj).absoluteString isEqualToString:expectedUrl]);
        }] withHeaders:[OCMArg checkWithBlock:^(id obj) {
            return (BOOL) ([headers count] ? [headers isEqualToDictionary:obj] : [obj count] == 0);
        }] size:CGSizeZero aspectLock:false];

        UAActionArguments *args = [UAActionArguments argumentsWithValue:value withSituation:[situationNumber integerValue]];
        [self verifyPerformWithArgs:args withExpectedUrl:expectedUrl withExpectedFetchResult:UAActionFetchResultNewData mockedViewController:mockedViewController];
    }
}

- (void)verifyPerformInForegroundWithValue:(id)value expectedUrl:(NSString *)expectedUrl expectedHeaders:(NSDictionary *)headers {
    [self commonVerifyPerformInForegroundWithValue:value expectedUrl:expectedUrl expectedHeaders:headers mockedViewController:self.mockOverlayViewController];
}

/**
 * Helper method to verify perform in foreground situations with no expected headers
 */
- (void)verifyPerformInForegroundWithValue:(id)value expectedUrl:(NSString *)expectedUrl {
    [self verifyPerformInForegroundWithValue:value expectedUrl:expectedUrl expectedHeaders:nil];
}

/**
 * Helper method to verify perform
 */
- (void)verifyPerformWithArgs:(UAActionArguments *)args withExpectedUrl:(NSString *)expectedUrl withExpectedFetchResult:(UAActionFetchResult)fetchResult mockedViewController:(id)mockedViewController {

    __block BOOL finished = NO;

    [self.action performWithArguments:args completionHandler:^(UAActionResult *result) {
        finished = YES;
        XCTAssertEqual(result.fetchResult, fetchResult,
                       @"fetch result %ld should match expect result %ld", result.fetchResult, fetchResult);
    }];

    [mockedViewController verify];

    XCTAssertTrue(finished, @"action should have completed");
}

/**
 * Helper method to verify accepts arguments
 */
- (void)verifyAcceptsArgumentsWithValue:(id)value shouldAccept:(BOOL)shouldAccept {
    NSArray *situations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                                     [NSNumber numberWithInteger:UASituationForegroundPush],
                                     [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                                     [NSNumber numberWithInteger:UASituationManualInvocation]];

    for (NSNumber *situationNumber in situations) {
        UAActionArguments *args = [UAActionArguments argumentsWithValue:value
                                                          withSituation:[situationNumber integerValue]];

        BOOL accepts = [self.action acceptsArguments:args];
        if (shouldAccept) {
            XCTAssertTrue(accepts, @"landing page action should accept value %@ in situation %@", value, situationNumber);
        } else {
            XCTAssertFalse(accepts, @"landing page action should not accept value %@ in situation %@", value, situationNumber);
        }
    }
}

@end
