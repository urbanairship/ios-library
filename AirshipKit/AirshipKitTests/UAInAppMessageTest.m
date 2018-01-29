/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAirship+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageAudience+Internal.h"

@interface UAInAppMessageTest : UABaseTest
@property(nonatomic, strong) NSDictionary *json;
@end

@implementation UAInAppMessageTest

- (void)testJSON {
    // setup
    NSDictionary *originalJSON = @{
                  @"message_id": @"blah",
                  @"display": @{@"body": @{
                                        @"text":@"the body"
                                        },
                                },
                  @"display_type": UAInAppMessageDisplayTypeBannerValue,
                  @"extras": @{@"foo":@"baz", @"baz":@"foo"},
                  @"audience": @{@"new_user" : @YES},
                  @"actions": @{@"cool":@"story"},
                  @"source": @"remote-data",
                  @"campaigns": @{ @"some": @"campaign info"}
                  };
    
    // test
    NSError *error;
    UAInAppMessage *messageFromOriginalJSON = [UAInAppMessage messageWithJSON:originalJSON error:&error];
    XCTAssertNotNil(messageFromOriginalJSON);
    XCTAssertNil(error);
    
    XCTAssertEqualObjects(@"blah",messageFromOriginalJSON.identifier);
    XCTAssertEqualObjects(@"the body",((UAInAppMessageBannerDisplayContent *)(messageFromOriginalJSON.displayContent)).body.text);
    XCTAssertEqual(UAInAppMessageDisplayTypeBanner, messageFromOriginalJSON.displayType);
    XCTAssertEqualObjects(@"baz",messageFromOriginalJSON.extras[@"foo"]);
    XCTAssertEqualObjects(@"foo",messageFromOriginalJSON.extras[@"baz"]);
    XCTAssertEqualObjects(@"story",messageFromOriginalJSON.actions[@"cool"]);
    XCTAssertEqualObjects(@YES, messageFromOriginalJSON.audience.isNewUser);
    XCTAssertEqualObjects(@{ @"some": @"campaign info"}, messageFromOriginalJSON.campaigns);
    XCTAssertEqual(UAInAppMessageSourceRemoteData, messageFromOriginalJSON.source);

    NSDictionary *toJSON = [messageFromOriginalJSON toJSON];
    XCTAssertNotNil(toJSON);
    UAInAppMessage *messageFromToJSON = [UAInAppMessage messageWithJSON:toJSON error:&error];
    XCTAssertNotNil(messageFromToJSON);
    XCTAssertNil(error);

    XCTAssertEqualObjects(messageFromOriginalJSON, messageFromToJSON);
}

- (void)testJSONDefaultSource {
    // setup
    NSDictionary *originalJSON = @{
                                   @"message_id": @"blah",
                                   @"display": @{@"body": @{
                                                         @"text":@"the body"
                                                         },
                                                 },
                                   @"display_type": UAInAppMessageDisplayTypeBannerValue,
                                   };

    NSArray *sources = @[@(UAInAppMessageSourceAppDefined),
                         @(UAInAppMessageSourceRemoteData),
                         @(UAInAppMessageSourceAppDefined)];

    for (NSNumber *source in sources) {
        NSInteger value = [source integerValue];
        NSError *error;
        UAInAppMessage *fromJSON = [UAInAppMessage messageWithJSON:originalJSON
                                                     defaultSource:value
                                                             error:&error];
        XCTAssertNotNil(fromJSON);
        XCTAssertNil(error);

        XCTAssertEqual(value, fromJSON.source);
    }
}

- (void)testJSONWithSource {
    // setup
    NSDictionary *originalJSON = @{
                                   @"message_id": @"blah",
                                   @"display": @{@"body": @{
                                                         @"text":@"the body"
                                                         },
                                                 },
                                   @"source": @"remote-data",
                                   @"display_type": UAInAppMessageDisplayTypeBannerValue,
                                   };


    NSError *error;
    UAInAppMessage *fromJSON = [UAInAppMessage messageWithJSON:originalJSON
                                                 defaultSource:UAInAppMessageSourceLegacyPush
                                                         error:&error];
    XCTAssertNotNil(fromJSON);
    XCTAssertNil(error);

    XCTAssertEqual(UAInAppMessageSourceRemoteData, fromJSON.source);
}

@end
