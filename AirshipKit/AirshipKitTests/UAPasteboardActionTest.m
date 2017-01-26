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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAPasteboardAction.h"
#import "UAActionArguments+Internal.h"

@interface UAPasteboardActionTest : XCTestCase
@property(nonatomic, strong) UAPasteboardAction *action;
@property(nonatomic, strong) id mockPasteboard;
@end

@implementation UAPasteboardActionTest

- (void)setUp {
    [super setUp];

    self.mockPasteboard = [OCMockObject niceMockForClass:[UIPasteboard class]];
    [[[self.mockPasteboard stub] andReturn:self.mockPasteboard] generalPasteboard];

    self.action = [UAPasteboardAction new];
}

- (void)tearDown {
    [self.mockPasteboard stopMocking];
    [super tearDown];
}

/**
 * Test accepts valid string arguments in foreground situations.
 */
- (void)testAcceptsArguments {
    UASituation validSituations[6] = {
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationAutomation
    };

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationBackgroundInteractiveButton;


    // Should accept an NSString
    arguments.value = @"pasteboard string";
    for (int i = 0; i < 6; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    // Should accept an NSDictionary with "text" 
    arguments.value = @{ @"text": @"pasteboard string"};
    for (int i = 0; i < 6; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }
}

/**
 * Test perform with a string sets the pasteboard's string
 */
- (void)testPerformWithString {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = @"pasteboard string";

    [[self.mockPasteboard expect] setString:@"pasteboard string"];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqual(arguments.value, result.value);
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockPasteboard verify];
}

/**
 * Test perform with a dictionary sets the pasteboard's string
 */
- (void)testPerformWithDictionary {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = @{@"text":  @"pasteboard string"};

    [[self.mockPasteboard expect] setString:@"pasteboard string"];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqual(arguments.value, result.value);
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockPasteboard verify];
}

@end
