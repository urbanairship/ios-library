/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAScheduleAudience+Internal.h"
#import "UATagSelector+Internal.h"

@import AirshipCore;

@interface UAScheduleAudienceTest : UABaseTest

@end

@implementation UAScheduleAudienceTest

- (void)testBuilderBlock {
    //setup
    __block NSError *error;
    UAScheduleAudience *originalAudience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
        builder.notificationsOptIn = @YES;
        builder.locationOptIn = @NO;
        builder.languageTags = @[@"en-us"];
        builder.tagSelector = [UATagSelector selectorWithJSON:@{
                                @"not" : @{
                                        @"tag":@"not-tag"
                                        }
                                } error:&error];

        UAJSONMatcher *matcher = [[UAJSONMatcher alloc] initWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"] scope:@[@"ios",@"version"]];
        builder.versionPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:matcher];
        builder.missBehavior = UAScheduleAudienceMissBehaviorSkip;
        builder.requiresAnalytics = @YES;
    }];
    
    // test
    UAScheduleAudience *fromJSON = [UAScheduleAudience audienceWithJSON:[originalAudience toJSON] error:&error];
    
    // verify
    XCTAssertEqualObjects(originalAudience, fromJSON);
    XCTAssertEqual(originalAudience.hash, fromJSON.hash);
    XCTAssertNil(error);
}

- (void)testNotValidMissBehavior {
    //setup
    __block NSError *error;
    UAScheduleAudience *originalAudience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {
        builder.notificationsOptIn = @YES;
        builder.locationOptIn = @NO;
        builder.languageTags = @[@"en-us"];
        builder.tagSelector = [UATagSelector selectorWithJSON:@{
                                                                            @"not" : @{
                                                                                    @"tag":@"not-tag"
                                                                                    }
                                                                            } error:&error];
        
        UAJSONMatcher *matcher = [[UAJSONMatcher alloc] initWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"] scope:@[@"ios",@"version"]];
        builder.versionPredicate = [[UAJSONPredicate alloc] initWithJSONMatcher:matcher];
        builder.missBehavior = UAScheduleAudienceMissBehaviorSkip;
    }];
    
    // test
    UAScheduleAudience *fromJSON = [UAScheduleAudience audienceWithJSON:[originalAudience toJSON] error:&error];

    // verify
    XCTAssertEqualObjects(originalAudience, fromJSON);
    XCTAssertEqual(originalAudience.hash, fromJSON.hash);
    XCTAssertNil(error);

    // use not valid miss behavior
    NSMutableDictionary *audienceAsJSON = [[originalAudience toJSON] mutableCopy];
    audienceAsJSON[@"miss_behavior"] = @"bad behavior";
    UAScheduleAudience *badBehaviorAudience = [UAScheduleAudience audienceWithJSON:audienceAsJSON error:&error];
    
    // verify
    XCTAssertNil(badBehaviorAudience);
    XCTAssertNotNil(error);
}

- (void)testAudienceMissBehaviorJSONParsing {
    // setup
    __block NSError *error;
    UAScheduleAudience *originalAudience = [UAScheduleAudience audienceWithBuilderBlock:^(UAScheduleAudienceBuilder *builder) {}];
    
    NSMutableDictionary *audienceAsJSON = [[originalAudience toJSON] mutableCopy];
    
    // test
    // default
    UAScheduleAudience *defaultBehaviorAudience = [UAScheduleAudience audienceWithJSON:audienceAsJSON error:&error];
    XCTAssertEqual(defaultBehaviorAudience.missBehavior, UAScheduleAudienceMissBehaviorPenalize);
    XCTAssertNil(error);
    
    // cancel
    audienceAsJSON[@"miss_behavior"] = @"cancel";
    UAScheduleAudience *cancelBehaviorAudience = [UAScheduleAudience audienceWithJSON:audienceAsJSON error:&error];
    XCTAssertEqual(cancelBehaviorAudience.missBehavior, UAScheduleAudienceMissBehaviorCancel);
    XCTAssertNil(error);

    // cancel
    audienceAsJSON[@"miss_behavior"] = @"skip";
    UAScheduleAudience *skipBehaviorAudience = [UAScheduleAudience audienceWithJSON:audienceAsJSON error:&error];
    XCTAssertEqual(skipBehaviorAudience.missBehavior, UAScheduleAudienceMissBehaviorSkip);
    XCTAssertNil(error);

    // cancel
    audienceAsJSON[@"miss_behavior"] = @"penalize";
    UAScheduleAudience *penalizeBehaviorAudience = [UAScheduleAudience audienceWithJSON:audienceAsJSON error:&error];
    XCTAssertEqual(penalizeBehaviorAudience.missBehavior, UAScheduleAudienceMissBehaviorPenalize);
    XCTAssertNil(error);
}

- (void)testFullJson {
    NSError *error;
    NSDictionary *json = @{ @"notification_opt_in": @(true),
                            @"location_opt_in": @(true),
                            @"locale": @[@"en-us"],
                            @"tags": @{
                                    @"and": @[@{
                                        @"not" : @{ @"tag": @"not-tag"}
                                        }, @{ @"tag": @"cool"}
                                        ]
                                    },
                            @"miss_behavior": @"cancel" };



    UAScheduleAudience *audience = [UAScheduleAudience
                                        audienceWithJSON:json
                                        error:&error];

    XCTAssertNil(error);
    XCTAssertEqualObjects(json, [audience toJSON]);
}


@end
