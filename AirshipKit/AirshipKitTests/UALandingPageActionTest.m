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
#import <OCMock/OCMock.h>
#import "UALandingPageAction.h"
#import "UAURLProtocol.h"
#import "UALandingPageOverlayController.h"
#import "UAAction+Internal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAUtils.h"

@interface UALandingPageActionTest : XCTestCase

@property (nonatomic, strong) id mockURLProtocol;
@property (nonatomic, strong) id mockLandingPageOverlayController;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockConfig;
@property (nonatomic, strong) UALandingPageAction *action;

@end

@implementation UALandingPageActionTest

- (void)setUp {
    [super setUp];
    self.action = [[UALandingPageAction alloc] init];
    self.mockURLProtocol = [OCMockObject niceMockForClass:[UAURLProtocol class]];
    self.mockLandingPageOverlayController = [OCMockObject niceMockForClass:[UALandingPageOverlayController class]];

    self.mockConfig = [OCMockObject niceMockForClass:[UAConfig class]];
    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockConfig] config];


    [[[self.mockConfig stub] andReturn:@"app-key"] appKey];
    [[[self.mockConfig stub] andReturn:kUAProductionLandingPageContentURL] landingPageContentURL];
    [[[self.mockConfig stub] andReturn:@"app-secret"] appSecret];
    [[[self.mockConfig stub] andReturnValue:OCMOCK_VALUE((NSUInteger)100)] cacheDiskSizeInMB];
}

- (void)tearDown {
    [self.mockLandingPageOverlayController stopMocking];
    [self.mockURLProtocol stopMocking];
    [self.mockAirship stopMocking];
    [self.mockConfig stopMocking];
    [super tearDown];
}

/**
 * Test accepts arguments
 */
- (void)testAcceptsArguments {
    [self verifyAcceptsArgumentsWithValue:@"foo.urbanairship.com" shouldAccept:true];
    [self verifyAcceptsArgumentsWithValue:@"https://foo.urbanairship.com" shouldAccept:true];
    [self verifyAcceptsArgumentsWithValue:@"http://foo.urbanairship.com" shouldAccept:true];
    [self verifyAcceptsArgumentsWithValue:@"file://foo.urbanairship.com" shouldAccept:true];
    [self verifyAcceptsArgumentsWithValue:[NSURL URLWithString:@"https://foo.urbanairship.com"] shouldAccept:true];

    // Verify UA content ID urls
    [self verifyAcceptsArgumentsWithValue:@"u:content-id" shouldAccept:true];
}

/**
 * Test accepts arguments rejects argument values that are unable to parsed
 * as a URL
 */
- (void)testAcceptsArgumentsNo {
    [self verifyAcceptsArgumentsWithValue:nil shouldAccept:false];
    [self verifyAcceptsArgumentsWithValue:[[NSObject alloc] init] shouldAccept:false];
    [self verifyAcceptsArgumentsWithValue:@[] shouldAccept:false];
    [self verifyAcceptsArgumentsWithValue:@"u:" shouldAccept:false];
}

/**
 * Test perform in UASituationBackgroundPush
 */
- (void)testPerformInForeground {
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
                                 expectedUrl:@"https://dl.urbanairship.com/aaa/app-key/%3C%7E%40rH7%2CASuTABk.%7E%3E"
                             expectedHeaders:@{@"Authorization": [UAUtils appAuthHeaderString]}];
}


/**
 * Helper method to verify perform in foreground situations
 */
- (void)verifyPerformInForegroundWithValue:(id)value expectedUrl:(NSString *)expectedUrl expectedHeaders:(NSDictionary *)headers {
    NSArray *situations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                                     [NSNumber numberWithInteger:UASituationForegroundPush],
                                     [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                                     [NSNumber numberWithInteger:UASituationManualInvocation],
                                     [NSNumber numberWithInteger:UASituationAutomation]];

    for (NSNumber *situationNumber in situations) {
        [[[self.mockLandingPageOverlayController expect] ignoringNonObjectArgs] showURL:[OCMArg checkWithBlock:^(id obj) {
            return (BOOL)([obj isKindOfClass:[NSURL class]] && [((NSURL *)obj).absoluteString isEqualToString:expectedUrl]);
        }] withHeaders:[OCMArg checkWithBlock:^(id obj) {
            return (BOOL) ([headers count] ? [headers isEqualToDictionary:obj] : [obj count] == 0);
        }] size:CGSizeZero aspectLock:false];

        UAActionArguments *args = [UAActionArguments argumentsWithValue:value withSituation:[situationNumber integerValue]];
        [self verifyPerformWithArgs:args withExpectedUrl:expectedUrl withExpectedFetchResult:UAActionFetchResultNewData];
    }
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
- (void)verifyPerformWithArgs:(UAActionArguments *)args withExpectedUrl:(NSString *)expectedUrl withExpectedFetchResult:(UAActionFetchResult)fetchResult {

    __block BOOL finished = NO;

    [[self.mockURLProtocol expect] addCachableURL:[OCMArg checkWithBlock:^(id obj) {
        return (BOOL)([obj isKindOfClass:[NSURL class]] && [((NSURL *)obj).absoluteString isEqualToString:expectedUrl]);
    }]];

    [self.action performWithArguments:args completionHandler:^(UAActionResult *result) {
        finished = YES;
        XCTAssertEqual(result.fetchResult, fetchResult,
                       @"fetch result %ld should match expect result %ld", result.fetchResult, fetchResult);
    }];

    [self.mockURLProtocol verify];
    [self.mockLandingPageOverlayController verify];

    XCTAssertTrue(finished, @"action should have completed");
}

/**
 * Helper method to verify accepts arguments
 */
- (void)verifyAcceptsArgumentsWithValue:(id)value shouldAccept:(BOOL)shouldAccept {
    NSArray *situations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                                     [NSNumber numberWithInteger:UASituationForegroundPush],
                                     [NSNumber numberWithInteger:UASituationBackgroundPush],
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
