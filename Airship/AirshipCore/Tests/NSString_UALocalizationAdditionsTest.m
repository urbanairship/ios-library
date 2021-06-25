/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "NSString+UALocalizationAdditions.h"

@import AirshipCore;

@interface NSString_UALocalizationAdditionsTest : UABaseTest
@end

@implementation NSString_UALocalizationAdditionsTest

/*
 Test that localizedStringWithTable:moduleBundle:defaultValue
   - correctly returns the localized string for a known receiver
   - returns the default value if the string can't be found due to a problematic table or key.
 */
- (void)testLocalizedStringWithTableModuleBundleDefaultValue {

    NSBundle *bundle = [UAirshipCoreResources bundle];

    NSString *localizedString = [@"ua_notification_button_yes" localizedStringWithTable:@"UrbanAirship"
                                                                           moduleBundle:bundle
                                                                           defaultValue:@"howdy"];
    XCTAssertEqualObjects(localizedString, @"Yes");

    NSString *badKeyString = [@"not_a_key" localizedStringWithTable:@"UrbanAirship" moduleBundle:bundle defaultValue:@"howdy"];

    XCTAssertEqualObjects(badKeyString, @"howdy");

    NSString *badTableString = [@"ua_notification_button_yes" localizedStringWithTable:@"NotATable"
                                                                          moduleBundle:bundle
                                                                          defaultValue:@"howdy"];

    XCTAssertEqualObjects(badTableString, @"howdy");
}

/*
 Test that localizedStringWithTable:moduleBundle
   - correctly returns the localized string for a known receiver
   - returns the key if the string can't be found due to a problematic table or key.
 */
- (void)testLocalizedStringWithTableModuleBundle {

    NSBundle *bundle = [UAirshipCoreResources bundle];

    NSString *localizedString = [@"ua_notification_button_yes" localizedStringWithTable:@"UrbanAirship"
                                                                           moduleBundle:bundle];
    XCTAssertEqualObjects(localizedString, @"Yes");

    NSString *badKeyString = [@"not_a_key" localizedStringWithTable:@"UrbanAirship"
                                                       moduleBundle:bundle];

    XCTAssertEqualObjects(badKeyString, @"not_a_key");

    NSString *badTableString = [@"ua_notification_button_yes" localizedStringWithTable:@"NotATable"
                                                                          moduleBundle:bundle];

    XCTAssertEqualObjects(badTableString, @"ua_notification_button_yes");
}


@end
