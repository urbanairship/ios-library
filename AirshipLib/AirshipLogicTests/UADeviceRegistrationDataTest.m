/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UADeviceRegistrationData.h"
#import "UADeviceRegistrationDataTest.h"

@implementation UADeviceRegistrationDataTest

- (void)testIsEqual {

    UADeviceRegistrationPayload *payload = [UADeviceRegistrationPayload payloadWithAlias:@"foo" withTags:nil withTimeZone:@"timezone" withQuietTime:nil withBadge:[NSNumber numberWithInteger:1]];

    //at this point the two instances should be equal by value
    UADeviceRegistrationData *data = [UADeviceRegistrationData dataWithDeviceToken:@"blah" withPayload:payload pushEnabled:NO];
    UADeviceRegistrationData *data2 = [UADeviceRegistrationData dataWithDeviceToken:@"blah" withPayload:payload pushEnabled:NO];

    XCTAssertEqualObjects(data, data2, @"UADeviceRegistrationData should compare by value, not by pointer");

    //the rest of these comparisons should result in inequality
    UADeviceRegistrationPayload *data3 = [UADeviceRegistrationData dataWithDeviceToken:@"adfsjlkfadsljk" withPayload:payload pushEnabled:NO];
    XCTAssertFalse([data isEqual:data3], @"changing the device token should trigger inequality");

    UADeviceRegistrationData *data4 = [UADeviceRegistrationData dataWithDeviceToken:@"blah" withPayload:payload pushEnabled:YES];
    XCTAssertFalse([data isEqual:data4], @"changing the push enabled status should trigger inequality");

    UADeviceRegistrationPayload *payload2 = [UADeviceRegistrationPayload payloadWithAlias:@"bar" withTags:nil withTimeZone:@"timezone" withQuietTime:nil withBadge:[NSNumber numberWithInteger:1]];
    UADeviceRegistrationData *data5 = [UADeviceRegistrationData dataWithDeviceToken:@"blah" withPayload:payload2 pushEnabled:NO];
    XCTAssertFalse([data isEqual:data5], @"changing the payload should trigger inequality");
}

@end
