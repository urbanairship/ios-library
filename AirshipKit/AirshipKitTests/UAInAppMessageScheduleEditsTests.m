/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageScheduleEdits+Internal.h"
#import "UABaseTest.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAUtils.h"
#import "UAScheduleInfo+Internal.h"

@interface UAInAppMessageScheduleEditsTests : UABaseTest

@end

@implementation UAInAppMessageScheduleEditsTests

- (void)testWithJSON {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:1000];
    NSDate *start = [NSDate date];

    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.identifier = @"test identifier";
        builder.extras = @{@"cool": @"story"};
        builder.displayContent = [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
            builder.placement = UAInAppMessageBannerPlacementTop;
            builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;


            UAInAppMessageTextInfo *heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Here is a headline!";
            }];
            builder.heading = heading;

            UAInAppMessageTextInfo *buttonTex = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Dismiss";
            }];

            UAInAppMessageButtonInfo *button = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
                builder.label = buttonTex;
                builder.identifier = @"button";
            }];

            builder.buttons = @[button];
        }];
    }];

    NSDictionary *editsJSON = @{ UAScheduleInfoLimitKey: @(1),
                                    UAScheduleInfoInAppMessageKey: [message toJSON],
                                    UAScheduleInfoEndKey:[[UAUtils ISODateFormatterUTCWithDelimiter] stringFromDate:end],
                                    UAScheduleInfoStartKey:[[UAUtils ISODateFormatterUTCWithDelimiter] stringFromDate:start],
                                    UAScheduleInfoEditGracePeriodKey: @(1),
                                    UAScheduleInfoIntervalKey: @(20)
                                    };

    NSError *error = nil;
    UAInAppMessageScheduleEdits *edits = [UAInAppMessageScheduleEdits editsWithJSON:editsJSON error:&error];

    XCTAssertEqual([edits.limit integerValue], 1);
    XCTAssertEqualObjects(edits.message, message);
    XCTAssertEqualWithAccuracy([edits.start timeIntervalSinceNow], [start timeIntervalSinceNow], 1);
    XCTAssertEqualWithAccuracy([edits.end timeIntervalSinceNow], [end timeIntervalSinceNow], 1);
    XCTAssertEqualWithAccuracy([edits.editGracePeriod doubleValue], 86400, 1);
    XCTAssertEqualWithAccuracy([edits.interval doubleValue], 20, 1);

    XCTAssertNil(error);
}

@end
