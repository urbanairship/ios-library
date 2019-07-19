/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageResolution+Internal.h"

@interface UAInAppMessageResolutionTest : UABaseTest
@end

@implementation UAInAppMessageResolutionTest

- (void)testButtonClickFromJSON {
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.identifier = @"identifier";
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.alignment = UAInAppMessageTextInfoAlignmentCenter;
            builder.text = @"text";
        }];

        builder.backgroundColor = [UIColor redColor];
    }];

    id buttonInfoJSON = [buttonInfo toJSON];

    UAInAppMessageResolution *resolution = [UAInAppMessageResolution resolutionWithJSON:@{@"type" : @"button_click", @"button_info" : buttonInfoJSON}
                                                                                  error:nil];

    XCTAssertNotNil(resolution);
    XCTAssertEqual(resolution.type, UAInAppMessageResolutionTypeButtonClick);
    XCTAssertEqualObjects(resolution.buttonInfo, buttonInfo);
}

- (void)testMessageClickFromJSON {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution resolutionWithJSON:@{@"type" : @"message_click"} error:nil];
    XCTAssertNotNil(resolution);
    XCTAssertEqual(resolution.type, UAInAppMessageResolutionTypeMessageClick);
}

- (void)testUserDismissedFromJSON {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution resolutionWithJSON:@{@"type" : @"user_dismissed"} error:nil];
    XCTAssertNotNil(resolution);
    XCTAssertEqual(resolution.type, UAInAppMessageResolutionTypeUserDismissed);
}

- (void)testTimedOutFromJSON {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution resolutionWithJSON:@{@"type" : @"timed_out"} error:nil];
    XCTAssertNotNil(resolution);
    XCTAssertEqual(resolution.type, UAInAppMessageResolutionTypeTimedOut);
}

@end
