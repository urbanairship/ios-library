/* Copyright 2017 Urban Airship and Contributors */

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
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockConfig;


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

    self.mockConfig = [OCMockObject niceMockForClass:[UAConfig class]];
    [[[self.mockConfig stub] andReturn:@"mockAppKey"] appKey];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockConfig] config];

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
    [self.mockConfig stopMocking];
    [self.mockAirship stopMocking];

    [super tearDown];
}

-(void)testSystemRatingDialog {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    [[self.mockStoreReviewController expect] requestReview];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :@"Acceptable Header", UARateAppLinkPromptBodyKey :@"Acceptable decsription."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockStoreReviewController verify];
}

-(void)rejectSystemRatingDialogLegacy {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;

    [[self.mockStoreReviewController reject] requestReview];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :@"Acceptable Header", UARateAppLinkPromptBodyKey :@"Acceptable decsription."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockStoreReviewController verify];
}

-(void)testDirectAppStoreLink {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    [[self.mockApplication expect] openURL:[NSURL URLWithString:@"itms-apps://itunes.apple.com/app/id1195168544?action=write-review"] options:@{} completionHandler:nil];
    [[[self.mockApplication stub] andReturnValue:@YES] canOpenURL:OCMOCK_ANY];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowLinkPromptKey:@NO, UARateAppLinkPromptTitleKey :@"Acceptable Header", UARateAppLinkPromptBodyKey :@"Acceptable decsription."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockApplication verify];
}

-(void)testDirectAppstoreLinkLegacy {
    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;

    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    [[self.mockApplication expect] openURL:[NSURL URLWithString:@"itms-apps://itunes.apple.com/app/id1195168544?action=write-review"]];
    [[[self.mockApplication stub] andReturnValue:@YES] canOpenURL:OCMOCK_ANY];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :@"Acceptable Header", UARateAppLinkPromptBodyKey :@"Acceptable decsription."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockStoreReviewController verify];
}

-(void)testlinkPrompt {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    NSString *acceptableHeader = @"Acceptable Header";
    NSString *acceptableDescription = @"Acceptable decsription.";

    [[self.mockRateAppPromptViewControler reject] displayWithHeader:acceptableHeader description:acceptableDescription completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        return YES;
    }]];

    [[[self.mockApplication stub] andReturnValue:@YES] canOpenURL:OCMOCK_ANY];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :acceptableHeader, UARateAppLinkPromptBodyKey :acceptableDescription} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockRateAppPromptViewControler verify];
}

-(void)testlinkPromptLegacy {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;

    NSString *acceptableHeader = @"Acceptable Header";
    NSString *acceptableDescription = @"Acceptable decsription.";

    [[self.mockRateAppPromptViewControler expect] displayWithHeader:acceptableHeader description:acceptableDescription completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        return YES;
    }]];

    [[[self.mockApplication stub] andReturnValue:@YES] canOpenURL:OCMOCK_ANY];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :acceptableHeader, UARateAppLinkPromptBodyKey :acceptableDescription} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
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

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :acceptableHeader, UARateAppLinkPromptBodyKey :acceptableDescription} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockRateAppPromptViewControler verify];
}

// Tests acceptable arguments are accepted in iOS 10.3+
- (void)testAcceptedArguments {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@1} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@0} shouldAccept:YES];

    // Accept header and description of proper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO, UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{} shouldAccept:YES];

    NSString *maxHeader = [@"" stringByPaddingToLength:24 withString:@"maxHeader" startingAtIndex:0];
    NSString *maxDescription = [@"" stringByPaddingToLength:50 withString:@"maxDecription" startingAtIndex:0];

    // Accept header and description of proper length if there's an itunes ID
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :maxHeader
, UARateAppLinkPromptBodyKey :maxDescription} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO, UARateAppLinkPromptTitleKey :maxHeader, UARateAppLinkPromptBodyKey :maxDescription} shouldAccept:YES];

    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@1, UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
}

// Tests acceptable arguments are accepted for the legacy implementation < 10.3
- (void)testAcceptedArgumentsLegacy {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@1} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@0} shouldAccept:YES];

    // Accept header and description of proper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES,  UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO,  UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{} shouldAccept:YES];

    NSString *maxHeader = [@"" stringByPaddingToLength:24 withString:@"maxHeader" startingAtIndex:0];
    NSString *maxDescription = [@"" stringByPaddingToLength:50 withString:@"maxDecription" startingAtIndex:0];

    // Accept header and description of proper length if there's an itunes ID
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES,  UARateAppLinkPromptTitleKey :maxHeader
                                            , UARateAppLinkPromptBodyKey :maxDescription} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO,  UARateAppLinkPromptTitleKey :maxHeader, UARateAppLinkPromptBodyKey :maxDescription} shouldAccept:YES];

    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES,  UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@1,  UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
}

// Tests that unacceptable arguments are rejected in iOS 10.3+
- (void)testRejectedArguments {

    // Don't accept a UARateAppAction without an iTunes ID key if show dialog is set to NO
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@0} shouldAccept:NO];

    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    NSString *tooLongHeader = [@"" stringByPaddingToLength:100 withString:@"maxDecription" startingAtIndex:0];
    NSString *tooLongDescription = [@"" stringByPaddingToLength:100 withString:@"maxDecription" startingAtIndex:0];

    //Reject header and decriptions of improper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES,  UARateAppLinkPromptTitleKey:tooLongHeader
                                            , UARateAppLinkPromptBodyKey : @"Acceptable description."} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES,  UARateAppLinkPromptTitleKey:@"Acceptable header."
                                            , UARateAppLinkPromptBodyKey : tooLongDescription} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO,  UARateAppLinkPromptTitleKey:tooLongHeader, UARateAppLinkPromptBodyKey : tooLongDescription} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:NO];
}

// Tests that unacceptable arguments are rejected for the legacy implementation < 10.3
- (void)testRejectedArgumentsLegacy {
    self.testOSMajorVersion = 9;
    self.testOSMinorVersion = 0;

    // Don't accept a UARateAppAction without an iTunes ID key if show dialog is set to NO
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@0} shouldAccept:NO];

    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    NSString *tooLongHeader = [@"" stringByPaddingToLength:100 withString:@"maxDecription" startingAtIndex:0];
    NSString *tooLongDescription = [@"" stringByPaddingToLength:100 withString:@"maxDecription" startingAtIndex:0];

    //Reject header and decriptions of improper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES,  UARateAppLinkPromptTitleKey:tooLongHeader
                                            , UARateAppLinkPromptBodyKey : @"Acceptable description."} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES,  UARateAppLinkPromptTitleKey:@"Acceptable header."
                                            , UARateAppLinkPromptBodyKey : tooLongDescription} shouldAccept:NO];

    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO,  UARateAppLinkPromptTitleKey:tooLongHeader, UARateAppLinkPromptBodyKey : tooLongDescription} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:NO];
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
