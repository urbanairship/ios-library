/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "UAIncomingInAppMessageAction.h"
#import "UAActionArguments+Internal.h"

@interface UAIncomingInAppMessageActionTest : XCTestCase
@property(nonatomic, strong) NSDictionary *payload;
@property(nonatomic, strong) UAIncomingInAppMessageAction *action;
@property(nonatomic, strong) UAActionArguments *arguments;
@end

@implementation UAIncomingInAppMessageActionTest

- (void)setUp {
    [super setUp];
    self.action = [UAIncomingInAppMessageAction new];

    id expiry = @"2020-12-15T11:45:22";
    id extra = @{@"foo":@"bar", @"baz":@12345};
    id display = @{@"alert":@"hi!", @"type":@"banner", @"duration":@20, @"position":@"top", @"primary_color":@"#ffffffff", @"secondary_color":@"#ff00ff00"};
    id actions = @{@"on_click":@{@"^d":@"http://google.com"}, @"button_group":@"ua_yes_no_foreground", @"button_actions":@{@"yes":@{@"^+t": @"yes_tag"}, @"no":@{@"^+t": @"no_tag"}}};

    self.payload = @{@"identifier":@"some identifier", @"expiry":expiry, @"extra":extra, @"display":display, @"actions":actions};

    self.arguments = [UAActionArguments argumentsWithValue:self.payload withSituation:UASituationManualInvocation];
}

- (void)tearDown {
    //teardown
    [super tearDown];
}

/**
 * Test that action accepts NSDictionary arguments in non-launched from push situations
 */
- (void)testAcceptsArguments {

    UASituation validSituations[5] = {
        UASituationForegroundPush,
        UASituationBackgroundPush,
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton,
        UASituationLaunchedFromPush
    };

    for (int i = 0; i < 5; i++) {
        self.arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept NSDictionary values and non-launch from push situations");
    }
}

/**
 * Test that action rejects argument values that are not dictionaries.
 */
- (void)testAcceptsArgumentsRejectsNonDictionaries {
    self.arguments.value = nil;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject a nil value");

    self.arguments.value = @"not a dictionary";
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject non-dictionary values");
}


@end
