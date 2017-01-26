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

#import "UAAction+Internal.h"
#import "UAAddTagsAction.h"
#import "UARemoveTagsAction.h"
#import "UAPush+Internal.h"
#import "UAActionArguments+Internal.h"
#import "UAirship.h"
#import "UANamedUser.h"

@interface UATagActionsTest : XCTestCase
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockNamedUser;

@property (nonatomic, strong) UAActionArguments *stringArgs;
@property (nonatomic, strong) UAActionArguments *arrayArgs;
@property (nonatomic, strong) UAActionArguments *emptyArrayArgs;
@property (nonatomic, strong) UAActionArguments *badArrayArgs;
@property (nonatomic, strong) UAActionArguments *numberArgs;
@property (nonatomic, strong) UAActionArguments *dictArgs;
@property (nonatomic, strong) UAActionArguments *dictIntKeysArgs;
@property (nonatomic, strong) UAActionArguments *dictIntValuesArgs;
@end

@implementation UATagActionsTest

- (void)setUp {
    [super setUp];
    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];
    self.mockNamedUser = [OCMockObject niceMockForClass:[UANamedUser class]];

    self.stringArgs = [UAActionArguments argumentsWithValue:@"hi" withSituation:UASituationWebViewInvocation];
    self.arrayArgs = [UAActionArguments argumentsWithValue:@[@"hi", @"there"] withSituation:UASituationManualInvocation];
    self.emptyArrayArgs = [UAActionArguments argumentsWithValue:@[] withSituation:UASituationForegroundPush];
    self.badArrayArgs = [UAActionArguments argumentsWithValue:@[@"hi", @10] withSituation:UASituationLaunchedFromPush];
    self.numberArgs = [UAActionArguments argumentsWithValue:@10 withSituation:UASituationWebViewInvocation];

    NSDictionary *channelDict = @{@"group1" : @[@"tag1", @"tag2"],@"group2" : @[@"tag3", @"tag4"]};
    NSDictionary *namedUserDict = @{@"group3" : @[@"tag5", @"tag6"]};
    NSDictionary *dict = @{@"channel" : channelDict, @"named_user" : namedUserDict};
    self.dictArgs = [UAActionArguments argumentsWithValue:dict withSituation:UASituationWebViewInvocation];

    NSDictionary *dictIntKeys = @{@1 : channelDict, @2 : namedUserDict};
    self.dictIntKeysArgs = [UAActionArguments argumentsWithValue:dictIntKeys withSituation:UASituationWebViewInvocation];
    
    NSDictionary *dictIntValues = @{@"channel" : @1, @"named_user" : @2};
    self.dictIntValuesArgs = [UAActionArguments argumentsWithValue:dictIntValues withSituation:UASituationWebViewInvocation];

    self.mockAirship = [OCMockObject niceMockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockAirship] shared];
    [[[self.mockAirship stub] andReturn:self.mockPush] push];
    [[[self.mockAirship stub] andReturn:self.mockNamedUser] namedUser];
}

- (void)tearDown {
    [self.mockAirship stopMocking];
    [self.mockNamedUser stopMocking];
    [self.mockAirship stopMocking];
    [super tearDown];
}

/**
 * Makes sure that the passed action rejects the background situation
 */
- (void)validateSituationForTagAction:(UAAction *)action {
    UASituation situations[6] = {
        UASituationLaunchedFromPush,
        UASituationForegroundPush,
        UASituationWebViewInvocation,
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton,
        UASituationAutomation
    };

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@[@"hey!"] withSituation:UASituationLaunchedFromPush];

    XCTAssertTrue([action acceptsArguments:args], @"nil situation should be acceptable");


    for (NSInteger i = 0; i < 6; i++) {
        args.situation = situations[i];
        NSLog(@"situation!: %ld", (long)args.situation);
        XCTAssertTrue([action acceptsArguments:args], @"any non-background situation should be valid");
    }

    args.situation = UASituationBackgroundPush;
    XCTAssertFalse([action acceptsArguments:args], @"background situation should be invalid");

    args.situation = UASituationLaunchedFromPush;
}

/**
 * Add/Remove tags should accept strings, empty arrays, and arrays of strings
 */
- (void)validateArgumentsForAddRemoveTagsAction:(UAAction *)action {
    [self validateSituationForTagAction:action];

    XCTAssertTrue([action acceptsArguments:self.stringArgs], @"strings should be accepted");
    XCTAssertTrue([action acceptsArguments:self.arrayArgs], @"arrays should be accepted");
    XCTAssertTrue([action acceptsArguments:self.emptyArrayArgs], @"empty arrays should be accepted");
    XCTAssertFalse([action acceptsArguments:self.badArrayArgs], @"arrays should only contain strings");
    XCTAssertFalse([action acceptsArguments:self.numberArgs], @"non arrays/strings should be rejected");
    XCTAssertTrue([action acceptsArguments:self.dictArgs], @"dictionaries should be accepted");
    XCTAssertFalse([action acceptsArguments:self.dictIntValuesArgs], @"dictionaries with non-array values should not be accepted");
    XCTAssertFalse([action acceptsArguments:self.dictIntKeysArgs], @"dictionaries with non-string keys should not be accepted");

}

/**
 * Set tags should accept empty arrays, and arrays of strings
 */
- (void)validateArgumentsForSetTagsAction:(UAAction *)action {
    [self validateSituationForTagAction:action];

    XCTAssertTrue([action acceptsArguments:self.arrayArgs], @"arrays should be accepted");
    XCTAssertTrue([action acceptsArguments:self.emptyArrayArgs], @"empty arrays should be accepted");
    XCTAssertFalse([action acceptsArguments:self.badArrayArgs], @"arrays should only contain strings");
    XCTAssertFalse([action acceptsArguments:self.stringArgs], @"strings should be rejected");
    XCTAssertFalse([action acceptsArguments:self.numberArgs], @"non arrays should be rejected");
    XCTAssertTrue([action acceptsArguments:self.dictArgs], @"dictionaries should be accepted");
    XCTAssertFalse([action acceptsArguments:self.dictIntValuesArgs], @"dictionaries with non-array values should not be accepted");
    XCTAssertFalse([action acceptsArguments:self.dictIntKeysArgs], @"dictionaries with non-string keys should not be accepted");}

/**
 * Checks argument validation and UAPush side effects of the add tags action
 */
- (void)testAddTagsAction {
    UAAddTagsAction *action = [[UAAddTagsAction alloc] init];
    [self validateArgumentsForAddRemoveTagsAction:action];

    [[self.mockPush expect] addTags:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.stringArgs
           completionHandler:^(UAActionResult *result) {
           [self.mockPush verify];
    }];

    [[self.mockPush expect] addTags:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.arrayArgs completionHandler:^(UAActionResult *result) {
           [self.mockPush verify];
    }];
    
    [[self.mockPush expect] addTags:@[@"tag1", @"tag2"] group:@"group1"];
    [[self.mockPush expect] addTags:@[@"tag3", @"tag4"] group:@"group2"];
    [[self.mockNamedUser expect] addTags:@[@"tag5", @"tag6"] group:@"group3"];
    [[self.mockPush expect] updateRegistration];
    [[self.mockNamedUser expect] updateTags];

    [action runWithArguments:self.dictArgs completionHandler:^(UAActionResult *result) {
        [self.mockPush verify];
        [self.mockNamedUser verify];
    }];
}

/**
 * Checks argument validation and UAPush side effects of the remove tags action
 */
- (void)testRemoveTagsAction {
    UARemoveTagsAction *action = [[UARemoveTagsAction alloc] init];

    [self validateArgumentsForAddRemoveTagsAction:action];

    [[self.mockPush expect] removeTags:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.stringArgs completionHandler:^(UAActionResult *result) {
           [self.mockPush verify];
    }];

    [[self.mockPush expect] removeTags:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.arrayArgs completionHandler:^(UAActionResult *result) {
           [self.mockPush verify];
    }];

    [[self.mockPush expect] removeTags:@[@"tag1", @"tag2"] group:@"group1"];
    [[self.mockPush expect] removeTags:@[@"tag3", @"tag4"] group:@"group2"];
    [[self.mockNamedUser expect] removeTags:@[@"tag5", @"tag6"] group:@"group3"];
    [[self.mockPush expect] updateRegistration];
    [[self.mockNamedUser expect] updateTags];
    
    [action runWithArguments:self.dictArgs completionHandler:^(UAActionResult *result) {
        [self.mockPush verify];
        [self.mockNamedUser verify];
    }];
}

@end
