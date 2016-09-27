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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@interface IOS8BugsTests : XCTestCase

@end

@implementation IOS8BugsTests

/**
 * Test for an iOS8 bug that causes UIUserNotificationAction's isEqual method to mutate the isDestructive and
 * isAuthenticationRequired bools. This bug is fixed in iOS9 s1.
 */
- (void)testUIUserNotificationActionIsEqualIsNotBroke {

    UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
    action.destructive = YES;
    action.authenticationRequired = YES;

    UIMutableUserNotificationAction *anotherAction = [[UIMutableUserNotificationAction alloc] init];
    anotherAction.destructive = NO;
    anotherAction.authenticationRequired = NO;

    // Verify the first action is destructive and requires authentication
    XCTAssertTrue(action.isDestructive);
    XCTAssertTrue(action.isAuthenticationRequired);

    // Compare
    [action isEqual:anotherAction];

    // Test that isEquals no longer mutates isDestructive and isAuthenticationRequired bools in iOS9+
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9, 0, 0}]) {
        // Verify the first action properties were NOT mutated
        XCTAssertTrue(action.isDestructive);
        XCTAssertTrue(action.isAuthenticationRequired);
    }
}

@end
