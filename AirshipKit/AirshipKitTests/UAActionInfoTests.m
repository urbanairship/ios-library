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
#import "UAActionScheduleInfo.h"
#import "UAUtils.h"

@interface UAActionInfoTests : XCTestCase

@end

@implementation UAActionInfoTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testWithJSON {

    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:1000];
    NSDate *start = [NSDate date];

    NSDictionary *scheduleJSON = @{ UAActionScheduleInfoGroupKey: @"test group",
                                    UAActionScheduleInfoLimitKey: @(1),
                                    UAActionScheduleInfoActionsKey: @{ @"action_name": @"action_value" },
                                    UAActionScheduleInfoEndKey:[[UAUtils ISODateFormatterUTC] stringFromDate:end],
                                    UAActionScheduleInfoStartKey:[[UAUtils ISODateFormatterUTC] stringFromDate:start],
                                    UAActionScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }] };

    NSError *error = nil;
    UAActionScheduleInfo *info = [UAActionScheduleInfo actionScheduleInfoWithJSON:scheduleJSON error:&error];

    XCTAssertEqualObjects(info.group, @"test group");
    XCTAssertEqual(info.limit, 1);
    XCTAssertEqualObjects(info.actions, @{ @"action_name": @"action_value" });
    XCTAssertEqualWithAccuracy([info.start timeIntervalSinceNow], [start timeIntervalSinceNow], 1);
    XCTAssertEqualWithAccuracy([info.end timeIntervalSinceNow], [end timeIntervalSinceNow], 1);
    XCTAssertEqual(info.triggers.count, 1);
    XCTAssertNil(error);
}

- (void)testRequiredJSONFields {
    // Minimum required fields
    NSDictionary *validJSON = @{ UAActionScheduleInfoActionsKey: @{ @"action_name": @"action_value" },
                                 UAActionScheduleInfoTriggersKey: @[ @{ UAScheduleTriggerTypeKey: UAScheduleTriggerAppForegroundName, UAScheduleTriggerGoalKey: @(1) }] };
    XCTAssertNotNil([UAActionScheduleInfo actionScheduleInfoWithJSON:validJSON error:nil]);

    for (NSString *key in validJSON.allKeys) {
        NSError *error = nil;
        NSMutableDictionary *invalidJSON = [validJSON mutableCopy];

        // Missing required value
        [invalidJSON removeObjectForKey:key];
        XCTAssertNil([UAActionScheduleInfo actionScheduleInfoWithJSON:invalidJSON error:&error]);
        XCTAssertNotNil(error);

        // Invalid valid
        error = nil;
        invalidJSON[key] = @"what";
        XCTAssertNil([UAActionScheduleInfo actionScheduleInfoWithJSON:invalidJSON error:&error]);
        XCTAssertNotNil(error);
    }
}

@end
