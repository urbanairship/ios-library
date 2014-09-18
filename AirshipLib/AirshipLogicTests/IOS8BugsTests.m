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
