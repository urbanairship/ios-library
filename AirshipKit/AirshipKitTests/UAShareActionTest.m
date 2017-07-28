/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAShareAction.h"
#import "UAActionArguments+Internal.h"

@interface UAShareActionTest : UABaseTest

@property (nonatomic, strong) UAActionArguments *arguments;
@property (nonatomic, strong) UAShareAction *action;
@end

@implementation UAShareActionTest

- (void)setUp {
    [super setUp];

    self.arguments = [[UAActionArguments alloc] init];
    self.arguments.situation = UASituationBackgroundInteractiveButton;

    self.action = [[UAShareAction alloc] init];
}

/**
 * Test accepts valid string arguments in foreground situations.
 */
- (void)testAcceptsArguments {
    self.arguments.value = @"some valid text";


    UASituation validSituations[6] = {
        UASituationForegroundPush,
        UASituationForegroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationAutomation
    };

    for (int i = 0; i < 6; i++) {
        self.arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept valid string URLs");
    }

}

/**
 * Test accepts arguments rejects background situations.
 */
- (void)testAcceptsArgumentsRejectsBackgroundSituations {
    self.arguments.value = @"some valid text";

    self.arguments.situation = UASituationBackgroundInteractiveButton;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject situation UASituationBackgroundInteractiveButton");

    self.arguments.situation = UASituationBackgroundPush;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject situation UASituationBackgroundPush");
}

/**
 * Test share action rejects argument values that are not strings.
 */
- (void)testAcceptsArgumentsRejectsNonStrings {
    self.arguments.situation = UASituationForegroundPush;

    self.arguments.value = nil;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should not accept a nil value");

    self.arguments.value = @3213;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should not accept non strings");

}

@end
