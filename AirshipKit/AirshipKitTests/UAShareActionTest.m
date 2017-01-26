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
#import "UAShareAction.h"
#import "UAActionArguments+Internal.h"

@interface UAShareActionTest : XCTestCase

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
