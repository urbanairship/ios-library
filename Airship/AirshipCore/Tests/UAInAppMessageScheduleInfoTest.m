/* Copyright Airship and Contributors */


#import "UAInAppMessageScheduleInfo+Internal.h"
#import "UABaseTest.h"

@interface UAInAppMessageScheduleInfoTest : UABaseTest

@end

@implementation UAInAppMessageScheduleInfoTest


- (void)testWithJSON {
    id json = @{@"triggers":@[@{@"type":@"active_session",@"goal": @(1)}], @"message":@{@"display_type":@"custom", @"message_id": @"c8d63228-bcde-45b0-82f3-7c3f4ec4e0ed", @"display": @{@"custom": @{@"cool": @"story"}}}};

    NSError *error = nil;
    UAInAppMessageScheduleInfo *info = [UAInAppMessageScheduleInfo scheduleInfoWithJSON:json source:UAInAppMessageSourceAppDefined error:&error];

    XCTAssertNotNil(info);
    XCTAssertNil(error);
    XCTAssertEqual(UAInAppMessageSourceAppDefined, info.message.source);

    info = [UAInAppMessageScheduleInfo scheduleInfoWithJSON:json source:UAInAppMessageSourceRemoteData error:&error];
    XCTAssertNotNil(info);
    XCTAssertNil(error);
    XCTAssertEqual(UAInAppMessageSourceRemoteData, info.message.source);
}

@end
