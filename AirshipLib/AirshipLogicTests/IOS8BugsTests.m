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

@interface IOS8BugsTests : XCTestCase

@end

@implementation IOS8BugsTests

/**
 * Test for UIUserNotificationAction isEqual mutates the desctructive and
 * authenticationRequired bools. Note: once this fails that means Apple fixed the
 * issue.
 */
- (void)testUIUserNotificationActionIsEqualIsBroke {
    UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
    action.destructive = YES;
    action.authenticationRequired = YES;

    UIMutableUserNotificationAction *anotherAction = [[UIMutableUserNotificationAction alloc] init];
    anotherAction.destructive = NO;
    anotherAction.authenticationRequired = NO;

    // Verify the first action is descrtructive and requires authentication
    XCTAssertTrue(action.isDestructive);
    XCTAssertTrue(action.isAuthenticationRequired);

    // Compare
    [action isEqual:anotherAction];

    // Verify the first action properties were mutated
    XCTAssertFalse(action.isDestructive);
    XCTAssertFalse(action.isAuthenticationRequired);
}

@end
