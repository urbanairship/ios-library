
#import <XCTest/XCTest.h>
#import "UALocalizationUtils.h"

@interface UALocalizationUtilsTest : XCTestCase
@end

@implementation UALocalizationUtilsTest

/*
 Test that localizdStringForKey:table:defaultValue
   * correctly returns the localized string for a known key
   * returns the default value if the string can't be found due to a problematic table or key.
 */
- (void)testLocalizedStringForKeyTableDefaultValue {

    NSString *localizedString = [UALocalizationUtils localizedStringForKey:@"ua_notification_button_yes" table:@"UAInteractiveNotifications" defaultValue:@"howdy"];
    XCTAssertEqualObjects(localizedString, @"Yes");

    NSString *badKeyString = [UALocalizationUtils localizedStringForKey:@"not_a_key" table:@"UAInteractiveNotifications" defaultValue:@"howdy"];

    XCTAssertEqualObjects(badKeyString, @"howdy");

    NSString *badTableString = [UALocalizationUtils localizedStringForKey:@"ua_notification_button_yes" table:@"NotATable" defaultValue:@"howdy"];

    XCTAssertEqualObjects(badTableString, @"howdy");
}

/*
 Test that localizdStringForKey:table
 * correctly returns the localized string for a known key
 * returns the key if the string can't be found due to a problematic table or key.
 */
- (void)testLocalizedStringForKeyTable {

    NSString *localizedString = [UALocalizationUtils localizedStringForKey:@"ua_notification_button_yes" table:@"UAInteractiveNotifications"];
    XCTAssertEqualObjects(localizedString, @"Yes");

    NSString *badKeyString = [UALocalizationUtils localizedStringForKey:@"not_a_key" table:@"UAInteractiveNotifications"];

    XCTAssertEqualObjects(badKeyString, @"not_a_key");

    NSString *badTableString = [UALocalizationUtils localizedStringForKey:@"ua_notification_button_yes" table:@"NotATable"];

    XCTAssertEqualObjects(badTableString, @"ua_notification_button_yes");
}


@end
