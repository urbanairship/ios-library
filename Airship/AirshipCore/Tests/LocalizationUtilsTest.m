/* Copyright Airship and Contributors */

#import "UABaseTest.h"

@import AirshipCore;
 
@interface LocalizationUtilsTest : UABaseTest
@end

@implementation LocalizationUtilsTest

/*
 Test that localizedStringWithTable:moduleBundle:defaultValue
 - correctly returns the localized string for a known receiver
 - returns the default value if the string can't be found due to a problematic table or key.
 */
- (void)testLocalizedStringWithTableModuleBundleDefaultValue {
    
    NSBundle *bundle = [UAirshipCoreResources bundle];
    
    NSString *localizedString = [UALocalizationUtils localizedString:@"ua_notification_button_yes" withTable:@"UrbanAirship"
                                                           moduleBundle:bundle
                                                           defaultValue:@"howdy"];
    XCTAssertEqualObjects(localizedString, @"Yes");
    
    NSString *badKeyString = [UALocalizationUtils localizedString:@"not_a_key" withTable:@"UrbanAirship" moduleBundle:bundle defaultValue:@"howdy"];
    
    XCTAssertEqualObjects(badKeyString, @"howdy");
    
    NSString *badTableString = [UALocalizationUtils localizedString:@"ua_notification_button_yes" withTable:@"NotATable"
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
    
    NSString *localizedString = [UALocalizationUtils localizedString:@"ua_notification_button_yes" withTable:@"UrbanAirship"
                                                           moduleBundle:bundle];
    XCTAssertEqualObjects(localizedString, @"Yes");
    
    NSString *badKeyString = [UALocalizationUtils localizedString:@"not_a_key" withTable:@"UrbanAirship"
                                                        moduleBundle:bundle];
    
    XCTAssertEqualObjects(badKeyString, @"not_a_key");
    
    NSString *badTableString = [UALocalizationUtils localizedString:@"ua_notification_button_yes" withTable:@"NotATable"
                                                           moduleBundle:bundle];
    
    XCTAssertEqualObjects(badTableString, @"ua_notification_button_yes");
}


@end
