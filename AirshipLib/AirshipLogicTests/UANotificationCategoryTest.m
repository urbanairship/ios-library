
#import <XCTest/XCTest.h>
#import "UANotificationCategory+Internal.h"
#import "UANotificationCategory.h"
#import "UANotificationAction.h"

@interface UANotificationCategoryTest : XCTestCase
@property(nonatomic, strong) UANotificationCategory *uaCategory;
@end

@implementation UANotificationCategoryTest

- (void)setUp {
    [super setUp];

    UNNotificationActionOptions watOptions = UNNotificationActionOptionForeground | UNNotificationActionOptionDestructive;

    UANotificationAction *watAction = [UANotificationAction actionWithIdentifier:@"wat" title:@"Wat" options:watOptions];

    UNNotificationActionOptions yayOptions = UNNotificationActionOptionForeground | UNNotificationActionOptionDestructive;
    UANotificationAction *yayAction = [UANotificationAction actionWithIdentifier:@"yay" title:@"Yay" options:yayOptions];

    NSArray *actions = @[watAction, yayAction];

    self.uaCategory = [UANotificationCategory categoryWithIdentifier:@"abilities" actions:actions intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
}

/**
 * Test the conversion of UAUserNotificationCategory to UIUserNotificationCategory
 */
- (void)testAsUIUserNotificationCategory {
    UIUserNotificationCategory *uiCategory = [self.uaCategory asUIUserNotificationCategory];
    XCTAssertTrue([self.uaCategory isEqualToUIUserNotificationCategory:(UIUserNotificationCategory *)uiCategory]);
}

- (void)testAsUNNotificationCategory {
    UNNotificationCategory *unCategory = [self.uaCategory asUNNotificationCategory];
    XCTAssertTrue([self.uaCategory isEqualToUNNotificationCategory:unCategory]);
}

@end
