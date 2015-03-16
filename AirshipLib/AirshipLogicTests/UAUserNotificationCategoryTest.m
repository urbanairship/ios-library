
#import <XCTest/XCTest.h>
#import "UAUserNotificationCategory+Internal.h"
#import "UAMutableUserNotificationCategory.h"
#import "UAMutableUserNotificationAction.h"

@interface UAUserNotificationCategoryTest : XCTestCase
@property(nonatomic, strong) UAMutableUserNotificationCategory *uaCategory;
@end

@implementation UAUserNotificationCategoryTest

- (void)setUp {
    [super setUp];
    self.uaCategory = [UAMutableUserNotificationCategory new];
    self.uaCategory.identifier = @"abilities";

    UAMutableUserNotificationAction *watAction = [UAMutableUserNotificationAction new];
    watAction.identifier = @"wat";
    watAction.title = @"Wat";
    watAction.destructive = YES;
    watAction.activationMode = UIUserNotificationActivationModeForeground;
    watAction.authenticationRequired = NO;

    UAMutableUserNotificationAction *yayAction = [UAMutableUserNotificationAction new];
    yayAction.identifier = @"yay";
    yayAction.title = @"Yay";
    yayAction.destructive = YES;
    yayAction.activationMode = UIUserNotificationActivationModeForeground;
    yayAction.authenticationRequired = NO;

    NSArray *actions = @[watAction, yayAction];

    [self.uaCategory setActions:actions forContext:UIUserNotificationActionContextMinimal];
    [self.uaCategory setActions:actions forContext:UIUserNotificationActionContextDefault];
}

- (void)testAsUIUserNotificationCategory {
    UIUserNotificationCategory *uiCategory = [self.uaCategory asUIUserNotificationCategory];
    XCTAssertTrue([self.uaCategory isEqualToCategory:(UAUserNotificationCategory *)uiCategory]);
}

@end
