/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import <StoreKit/StoreKit.h>
#import "UAAction+Internal.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UARateAppAction.h"
#import "UARateAppPromptViewController+Internal.h"

@interface UARateAppActionTest : UABaseTest

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

    self.mockProcessInfo = [self mockForClass:[NSProcessInfo class]];
    [[[self.mockProcessInfo stub] andReturn:self.mockProcessInfo] processInfo];

    self.mockRateAppPromptViewControler = [self mockForClass:[UARateAppPromptViewController class]];
    [[[self.mockRateAppPromptViewControler stub] andReturn:self.mockRateAppPromptViewControler] alloc];
    id shutUp = [[[self.mockRateAppPromptViewControler stub] andReturn:self.mockRateAppPromptViewControler] initWithNibName:OCMOCK_ANY bundle:OCMOCK_ANY];
    [shutUp self];

    self.mockConfig = [self mockForClass:[UAConfig class]];
    [[[self.mockConfig stub] andReturn:@"mockAppKey"] appKey];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockConfig] config];

    self.mockApplication = [self mockForClass:[UIApplication class]];
    [[[self.mockApplication stub] andReturn:self.mockApplication] sharedApplication];

    [[[[self.mockProcessInfo stub] andDo:^(NSInvocation *invocation) {
        NSOperatingSystemVersion arg;
        [invocation getArgument:&arg atIndex:2];

        BOOL result = self.testOSMajorVersion >= arg.majorVersion &&
        self.testOSMinorVersion >= arg.minorVersion;
        [invocation setReturnValue:&result];
    }] ignoringNonObjectArgs] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){0, 0, 0}];

    [SKStoreReviewController requestReview];

    self.mockStoreReviewController = [self mockForClass:[SKStoreReviewController class]];

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

// Tests removal of timestamps more than one year old
- (void)testTimestampRemovalDataStore {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    UAPreferenceDataStore *dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:[UAirship shared].config.appKey];

    // Remove all keys to avoid test pollution
    [dataStore removeAll];

    NSNumber *todayTimestamp = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];

    // Inject time stamps of zero one and two to indicate three timestamps long ago
    [[NSUserDefaults standardUserDefaults] setObject:@[@0, @1, @2] forKey:[@"mockAppKey" stringByAppendingString:@"RateAppActionPromptCount"]];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Make sure there are stored timestamps
    NSArray *timestamps = [dataStore arrayForKey:@"RateAppActionPromptCount"];
    XCTAssertTrue([timestamps containsObject:@0] && [timestamps containsObject:@1] && [timestamps containsObject:@2]);

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :@"Acceptable Header", UARateAppLinkPromptBodyKey :@"Acceptable description."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    // Check timestamps after call to ensure long ago timestamps are removed and today's timestamp is present
    timestamps = [dataStore arrayForKey:@"RateAppActionPromptCount"];
    XCTAssertFalse([timestamps containsObject:@0] || [timestamps containsObject:@1] || [timestamps containsObject:@2]);
    NSNumber *storedTimestamp = timestamps[0];
    XCTAssertTrue((storedTimestamp.doubleValue-todayTimestamp.doubleValue) < 5);

    // Remove all keys to avoid test pollution
    [dataStore removeAll];
}


-(void)testSystemRatingDialog {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    [[self.mockStoreReviewController expect] requestReview];

    [self.action performWithArguments:[UAActionArguments argumentsWithValue:@{ UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :@"Acceptable Header", UARateAppLinkPromptBodyKey :@"Acceptable decsription."} withSituation:UASituationManualInvocation] completionHandler:^(UAActionResult * result) {
    }];

    [self.mockStoreReviewController verify];
}

-(void)testRejectSystemRatingDialogLegacy {
    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    self.testOSMajorVersion = 10;
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

    self.testOSMajorVersion = 10;
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
    self.testOSMajorVersion = 10;
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

    // Accept when itunes ID link prompt flag and itunes ID argument are set
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES, UARateAppItunesIDKey:@"1111111111"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO, UARateAppItunesIDKey:@"1111111111"} shouldAccept:YES];

    // Accept header and description of proper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES, UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO, UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];

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
    self.testOSMajorVersion = 10;
    self.testOSMinorVersion = 0;

    // Accept when itunes ID link prompt flag and itunes ID argument are set
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES, UARateAppItunesIDKey:@"1111111111"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO, UARateAppItunesIDKey:@"1111111111"} shouldAccept:YES];

    [[[self.mockConfig stub] andReturn:@"1195168544"] itunesID];

    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@1} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@0} shouldAccept:YES];

    // Accept header and description of proper length
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES,  UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO,  UARateAppLinkPromptTitleKey :@"A header", UARateAppLinkPromptBodyKey :@"a descriptiion"} shouldAccept:YES];

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

    // Reject empty itunes ID arg
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES, UARateAppItunesIDKey:@""} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO, UARateAppItunesIDKey:@""} shouldAccept:NO];

    // Don't accept a UARateAppAction without an iTunes ID
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@1} shouldAccept:NO];
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

    [self verifyAcceptsArgumentsWithValue:@{} shouldAccept:NO];
}

// Tests that unacceptable arguments are rejected for the legacy implementation < 10.3
- (void)testRejectedArgumentsLegacy {
    self.testOSMajorVersion = 10;
    self.testOSMinorVersion = 0;

    // Reject empty itunes ID arg
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES, UARateAppItunesIDKey:@""} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO, UARateAppItunesIDKey:@""} shouldAccept:NO];

    // Don't accept a UARateAppAction without an iTunes ID key
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@YES} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@NO} shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@{UARateAppShowLinkPromptKey:@1} shouldAccept:NO];
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

    [self verifyAcceptsArgumentsWithValue:@{} shouldAccept:NO];
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
