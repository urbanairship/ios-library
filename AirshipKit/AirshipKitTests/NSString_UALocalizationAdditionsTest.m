/* Copyright Urban Airship and Contributors */

#import "UABaseTest.h"
#import "NSString+UALocalizationAdditions.h"

@interface NSString_UALocalizationAdditionsTest : UABaseTest
@end

@implementation NSString_UALocalizationAdditionsTest

/*
 Test that localizedStringWithTable:defaultValue
   - correctly returns the localized string for a known receiver
   - returns the default value if the string can't be found due to a problematic table or key.
 */
- (void)testLocalizedStringWithTableDefaultValue {

    NSString *localizedString = [@"ua_notification_button_yes" localizedStringWithTable:@"UrbanAirship" defaultValue:@"howdy"];
    XCTAssertEqualObjects(localizedString, @"Yes");

    NSString *badKeyString = [@"not_a_key" localizedStringWithTable:@"UrbanAirship" defaultValue:@"howdy"];

    XCTAssertEqualObjects(badKeyString, @"howdy");

    NSString *badTableString = [@"ua_notification_button_yes" localizedStringWithTable:@"NotATable" defaultValue:@"howdy"];

    XCTAssertEqualObjects(badTableString, @"howdy");
}

/*
 Test that localizedStringWithTable
   - correctly returns the localized string for a known receiver
   - returns the key if the string can't be found due to a problematic table or key.
 */
- (void)testLocalizedStringWithTable {

    NSString *localizedString = [@"ua_notification_button_yes" localizedStringWithTable:@"UrbanAirship"];
    XCTAssertEqualObjects(localizedString, @"Yes");

    NSString *badKeyString = [@"not_a_key" localizedStringWithTable:@"UrbanAirship"];

    XCTAssertEqualObjects(badKeyString, @"not_a_key");

    NSString *badTableString = [@"ua_notification_button_yes" localizedStringWithTable:@"NotATable"];

    XCTAssertEqualObjects(badTableString, @"ua_notification_button_yes");
}


@end
