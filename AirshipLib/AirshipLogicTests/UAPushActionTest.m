/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import "UAPushAction.h"

@interface UAPushActionTest : XCTestCase

@end

@implementation UAPushActionTest

UAPushActionArguments *validPushArguments;

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

/*
 * Tests that UAPushActions only accepts UAPushArguments
 */
- (void)testAcceptsArguments {
    UAPushAction *action = [[UAPushAction alloc] init];

    XCTAssertTrue([action acceptsArguments:[[UAPushActionArguments alloc] init]], @"Push action should only accept UAPushActionArguments");
    XCTAssertFalse([action acceptsArguments:[[UAActionArguments alloc] init]], @"Push action should only accept UAPushActionArguments");
}

/*
 * Test performWithArguments:withCompletionHandler: calls 
 * performWithArguments:withCompletionHandler with the push arguments
 */
- (void)testPerformWithArguments {
    __block BOOL didActionRun = false;
    __block BOOL didCompletionHandlerRun = false;

    UAActionArguments *arguments = [[UAPushActionArguments alloc] init];
    UAActionResult *result = [UAActionResult none];

    UAPushAction *action = [UAPushAction pushActionWithBlock:^(UAPushActionArguments *args, UAActionPushCompletionHandler completionHandler) {
        didActionRun = true;
        XCTAssertEqualObjects(arguments, args, @"performWithArgumnets should pass arguments to performWithPushArguments");
        completionHandler(result);
    }];

    [action performWithArguments:arguments withCompletionHandler:^(UAActionResult *finalResult) {
        didCompletionHandlerRun = true;
        XCTAssertEqualObjects(result, finalResult, @"performWithArgumnets should pass the result to the completion handler");
    }];

    XCTAssertTrue(didActionRun, @"Action did not perform");
    XCTAssertTrue(didCompletionHandlerRun, @"Completion handler was not called");
}


@end
