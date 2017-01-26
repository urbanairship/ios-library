/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import <XCTest/XCTest.h>
#import "NSString+UALocalizationAdditions.h"

@interface NSString_UALocalizationAdditionsTest : XCTestCase
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
