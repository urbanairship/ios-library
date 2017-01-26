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
#import "UAAssociatedIdentifiers.h"

@interface UAAssociatedIdentifiersTest : XCTestCase
@end

@implementation UAAssociatedIdentifiersTest

/**
 * Test identifier ID mapping
 */
- (void)testIDs {
    UAAssociatedIdentifiers *identifiers = [UAAssociatedIdentifiers identifiersWithDictionary:@{@"custom key": @"custom value"}];
    identifiers.vendorID = @"vendor ID";
    identifiers.advertisingID = @"advertising ID";
    identifiers.advertisingTrackingEnabled = NO;
    [identifiers setIdentifier:@"another custom value" forKey:@"another custom key"];

    XCTAssertEqualObjects(@"vendor ID", identifiers.allIDs[@"com.urbanairship.vendor"]);
    XCTAssertEqualObjects(@"advertising ID", identifiers.allIDs[@"com.urbanairship.idfa"]);
    XCTAssertFalse(identifiers.advertisingTrackingEnabled);
    XCTAssertEqualObjects(@"true", identifiers.allIDs[@"com.urbanairship.limited_ad_tracking_enabled"]);
    XCTAssertEqualObjects(@"another custom value", identifiers.allIDs[@"another custom key"]);

    identifiers.advertisingTrackingEnabled = YES;
    XCTAssertTrue(identifiers.advertisingTrackingEnabled);
    XCTAssertEqualObjects(@"false", identifiers.allIDs[@"com.urbanairship.limited_ad_tracking_enabled"]);
}

/**
 * Test creating associated identifiers with invalid dictionary
 */
- (void)testAssociateDeviceIdentifiersInvalidDictionary {

    NSDictionary *invalidDictionary = @{@"some identifier": @2};
    UAAssociatedIdentifiers *identifiers = [UAAssociatedIdentifiers identifiersWithDictionary:invalidDictionary];
    XCTAssertEqual(identifiers.allIDs.count, 0, @"Should be empty associated identifiers instance.");

    NSDictionary *anotherInvalidDictionary = @{@2: @"identifier"};
    UAAssociatedIdentifiers *someIdentifiers = [UAAssociatedIdentifiers identifiersWithDictionary:anotherInvalidDictionary];
    XCTAssertEqual(someIdentifiers.allIDs.count, 0, @"Should be empty associated identifiers instance.");
}

@end
