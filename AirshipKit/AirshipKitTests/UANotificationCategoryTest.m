
#import <XCTest/XCTest.h>
#import "UANotificationCategory.h"
#import "UANotificationAction.h"
#import "UATextInputNotificationAction.h"

@interface UANotificationCategoryTest : XCTestCase
@property(nonatomic, strong) UANotificationCategory *uaCategory;
@end

@implementation UANotificationCategoryTest

- (void)setUp {
    [super setUp];

    UNNotificationActionOptions watOptions = UNNotificationActionOptionForeground | UNNotificationActionOptionDestructive;

    UANotificationAction *watAction = [UANotificationAction actionWithIdentifier:@"wat" title:@"Wat" options:(UANotificationActionOptions)watOptions];

    UNNotificationActionOptions yayOptions = UNNotificationActionOptionForeground | UNNotificationActionOptionDestructive;
    UANotificationAction *yayAction = [UANotificationAction actionWithIdentifier:@"yay" title:@"Yay" options:(UANotificationActionOptions)yayOptions];

    UNNotificationActionOptions zizOptions = UNNotificationActionOptionDestructive;
    UATextInputNotificationAction *zizAction = [UATextInputNotificationAction actionWithIdentifier:@"ziz" title:@"Ziz" textInputButtonTitle:@"ziz button" textInputPlaceholder:@"ziz placeholder" options:(UANotificationActionOptions)zizOptions];
    
    NSArray *actions = @[watAction, yayAction, zizAction];

    self.uaCategory = [UANotificationCategory categoryWithIdentifier:@"abilities" actions:actions intentIdentifiers:@[] options:UANotificationCategoryOptionNone];
}

/**
 * Test the conversion of UAUserNotificationCategory to UIUserNotificationCategory
 */
- (void)testAsUIUserNotificationCategory {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    UIUserNotificationCategory *uiCategory = [self.uaCategory asUIUserNotificationCategory];
    XCTAssertTrue([self.uaCategory isEqualToUIUserNotificationCategory:(UIUserNotificationCategory *)uiCategory]);
#pragma GCC diagnostic pop
}

- (void)testAsUNNotificationCategory {
    UNNotificationCategory *unCategory = [self.uaCategory asUNNotificationCategory];
    XCTAssertTrue([self.uaCategory isEqualToUNNotificationCategory:unCategory]);
}

@end
