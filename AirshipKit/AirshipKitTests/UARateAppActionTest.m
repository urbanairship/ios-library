/*
Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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
#import <StoreKit/StoreKit.h>
#import <OCMock/OCMock.h>
#import "UAAction+Internal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UARateAppAction.h"
#import "UARateAppPromptViewController+Internal.h"

@interface UARateAppActionTest : XCTestCase

@property (nonatomic, strong) id mockProcessInfo;
@property (nonatomic, strong) id mockApplication;
@property (nonatomic, strong) id mockStoreReviewController;
@property (nonatomic, strong) id mockRateAppPromptViewControler;

@property (assign) int testOSMajorVersion;
@property (assign) int testOSMinorVersion;

@property (nonatomic, retain) UARateAppAction *action;
@end

@implementation UARateAppActionTest

- (void)setUp {
    [super setUp];

    // Set default OS major version to 10 by default
    self.testOSMajorVersion = 10;
    self.testOSMinorVersion = 3;

    self.mockProcessInfo = [OCMockObject niceMockForClass:[NSProcessInfo class]];
    [[[self.mockProcessInfo stub] andReturn:self.mockProcessInfo] processInfo];

    self.mockRateAppPromptViewControler = [OCMockObject niceMockForClass:[UARateAppPromptViewController class]];
    [[[self.mockRateAppPromptViewControler stub] andReturn:self.mockRateAppPromptViewControler] alloc];
    id shutUp = [[[self.mockRateAppPromptViewControler stub] andReturn:self.mockRateAppPromptViewControler] initWithNibName:OCMOCK_ANY bundle:OCMOCK_ANY];
    [shutUp self];

    self.mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];

    [[[[self.mockProcessInfo stub] andDo:^(NSInvocation *invocation) {
        NSOperatingSystemVersion arg;
        [invocation getArgument:&arg atIndex:2];

        BOOL result = self.testOSMajorVersion >= arg.majorVersion &&
        self.testOSMinorVersion >= arg.minorVersion;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){0, 0, 0}];

    [SKStoreReviewController requestReview];

    self.mockStoreReviewController = [OCMockObject niceMockForClass:[SKStoreReviewController class]];

    self.action = [[UARateAppAction alloc] init];
}

- (void)tearDown {
    [self.mockApplication stopMocking];
    [self.mockProcessInfo stopMocking];
    [self.mockStoreReviewController stopMocking];
    [self.mockRateAppPromptViewControler stopMocking];

    [super tearDown];
}

-(void)testSystemRatingDialog {
    [[self.mockStoreReviewController expect] requestReview];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"Acceptable Header", UARateAppLinkPromptDescriptionKey :@"Acceptable decsription."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockStoreReviewController verify];
}

-(void)rejectSystemRatingDialogLegacy {
    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;

    [[self.mockStoreReviewController reject] requestReview];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"Acceptable Header", UARateAppLinkPromptDescriptionKey :@"Acceptable decsription."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockStoreReviewController verify];
}

-(void)testDirectAppStoreLink {
    [[self.mockApplication expect] openURL:[NSURL URLWithString:@"itms-apps://itunes.apple.com/app/id1195168544?action=write-review"] options:@{} completionHandler:nil];
    [[[self.mockApplication stub] andReturnValue:@YES] canOpenURL:OCMOCK_ANY];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowDialogKey:@NO, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"Acceptable Header", UARateAppLinkPromptDescriptionKey :@"Acceptable decsription."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockApplication verify];
}

-(void)testDirectAppstoreLinkLegacy {
    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;

    [[self.mockApplication expect] openURL:[NSURL URLWithString:@"itms-apps://itunes.apple.com/app/id1195168544?action=write-review"]];
    [[[self.mockApplication stub] andReturnValue:@YES] canOpenURL:OCMOCK_ANY];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"Acceptable Header", UARateAppLinkPromptDescriptionKey :@"Acceptable decsription."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockStoreReviewController verify];
}

-(void)testlinkPrompt {
    NSString *acceptableHeader = @"Acceptable Header";
    NSString *acceptableDescription = @"Acceptable decsription.";

    [[self.mockRateAppPromptViewControler reject] displayWithHeader:acceptableHeader description:acceptableDescription completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        return YES;
    }]];

    [[[self.mockApplication stub] andReturnValue:@YES] canOpenURL:OCMOCK_ANY];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :acceptableHeader, UARateAppLinkPromptDescriptionKey :acceptableDescription} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockRateAppPromptViewControler verify];
}

-(void)testlinkPromptLegacy {
    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;

    NSString *acceptableHeader = @"Acceptable Header";
    NSString *acceptableDescription = @"Acceptable decsription.";

    [[self.mockRateAppPromptViewControler expect] displayWithHeader:acceptableHeader description:acceptableDescription completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        return YES;
    }]];

    [[[self.mockApplication stub] andReturnValue:@YES] canOpenURL:OCMOCK_ANY];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :acceptableHeader, UARateAppLinkPromptDescriptionKey :acceptableDescription} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockRateAppPromptViewControler verify];
}


-(void)testlinkPromptBadURLLegacy {
    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;

    NSString *acceptableHeader = @"Acceptable Header";
    NSString *acceptableDescription = @"Acceptable decsription.";

    [[self.mockRateAppPromptViewControler reject] displayWithHeader:acceptableHeader description:acceptableDescription completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        return YES;
    }]];

    [[[self.mockApplication stub] andReturnValue:@NO] canOpenURL:OCMOCK_ANY];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :acceptableHeader, UARateAppLinkPromptDescriptionKey :acceptableDescription} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockRateAppPromptViewControler verify];
}

// Tests acceptable arguments are accepted in iOS 10.3+
- (void)testAcceptedArguments {
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO, UARateAppItunesIDKey : @"1195168544"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@1, UARateAppItunesIDKey : @"1195168544"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@0, UARateAppItunesIDKey : @"1195168544"} shouldAccept:YES];

    // Accept header and description of proper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:YES];

    NSString *maxHeader = [@"" stringByPaddingToLength:24 withString:@"maxHeader" startingAtIndex:0];
    NSString *maxDescription = [@"" stringByPaddingToLength:50 withString:@"maxDecription" startingAtIndex:0];

    // Accept header and description of proper length if there's an itunes ID
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :maxHeader
, UARateAppLinkPromptDescriptionKey :maxDescription} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :maxHeader, UARateAppLinkPromptDescriptionKey :maxDescription} shouldAccept:YES];

    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@1, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:YES];
}

// Tests acceptable arguments are accepted for the legacy implementation < 10.3
- (void)testAcceptedArgumentsLegacy {
    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO, UARateAppItunesIDKey : @"1195168544"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@1, UARateAppItunesIDKey : @"1195168544"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@0, UARateAppItunesIDKey : @"1195168544"} shouldAccept:YES];

    // Accept header and description of proper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:YES];

    NSString *maxHeader = [@"" stringByPaddingToLength:24 withString:@"maxHeader" startingAtIndex:0];
    NSString *maxDescription = [@"" stringByPaddingToLength:50 withString:@"maxDecription" startingAtIndex:0];

    // Accept header and description of proper length if there's an itunes ID
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :maxHeader
                                            , UARateAppLinkPromptDescriptionKey :maxDescription} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :maxHeader, UARateAppLinkPromptDescriptionKey :maxDescription} shouldAccept:YES];

    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@1, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:YES];
}

// Tests that unacceptable arguments are rejected in iOS 10.3+
- (void)testRejectedArguments {
    // Don't accept a UARateAppAction without an iTunes ID key if show dialog is set to NO
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@0} shouldAccept:NO];

    NSString *tooLongHeader = [@"" stringByPaddingToLength:100 withString:@"maxDecription" startingAtIndex:0];
    NSString *tooLongDescription = [@"" stringByPaddingToLength:100 withString:@"maxDecription" startingAtIndex:0];

    //Reject header and decriptions of improper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey:tooLongHeader
                                            , UARateAppLinkPromptDescriptionKey : tooLongDescription} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey:tooLongHeader, UARateAppLinkPromptDescriptionKey : tooLongDescription} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:NO];
}

// Tests that unacceptable arguments are rejected for the legacy implementation < 10.3
- (void)testRejectedArgumentsLegacy {
    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;

    // Don't accept a UARateAppAction without an iTunes ID key if show dialog is set to NO
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@0} shouldAccept:NO];

    NSString *tooLongHeader = [@"" stringByPaddingToLength:100 withString:@"maxDecription" startingAtIndex:0];
    NSString *tooLongDescription = [@"" stringByPaddingToLength:100 withString:@"maxDecription" startingAtIndex:0];

    //Reject header and decriptions of improper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@YES, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey:tooLongHeader
                                            , UARateAppLinkPromptDescriptionKey : tooLongDescription} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowDialogKey:@NO, UARateAppItunesIDKey : @"1195168544", UARateAppLinkPromptHeaderKey:tooLongHeader, UARateAppLinkPromptDescriptionKey : tooLongDescription} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppLinkPromptHeaderKey :@"A header", UARateAppLinkPromptDescriptionKey :@"a descriptiion"} shouldAccept:NO];
}

/**
 * Helper method to verify acceptable arguments for each accepted situation
 */
- (void)verifyAcceptsArgumentsWithValue:(id)value shouldAccept:(BOOL)shouldAccept {
    NSArray *acceptedSituations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                            [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                            [NSNumber numberWithInteger:UASituationAutomation],
                            [NSNumber numberWithInteger:UASituationForegroundInteractiveButton],
                            [NSNumber numberWithInteger:UASituationManualInvocation]];

    for (NSNumber *situationNumber in acceptedSituations) {
        UAActionArguments *args = [UAActionArguments argumentsWithValue:value
                                                          withSituation:[situationNumber integerValue]];

        BOOL accepts = [self.action acceptsArguments:args];
        if (shouldAccept) {
            XCTAssertTrue(accepts, @"Rate app action should accept value %@ in situation %@", value, situationNumber);
        } else {
            XCTAssertFalse(accepts, @"Rate app action should not accept value %@ in situation %@", value, situationNumber);
        }
    }
}

@end
