/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAVersionMatcher+Internal.h"
#import "UAInAppMessageTagSelector+Internal.h"
#import "UAJSONPredicate.h"

@interface UAInAppMessageAudienceTest : UABaseTest

@end

@implementation UAInAppMessageAudienceTest

- (void)testBuilderBlock {
    //setup
    __block NSError *error;
    UAInAppMessageAudience *originalAudience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
        builder.isNewUser = @YES;
        builder.notificationsOptIn = @YES;
        builder.locationOptIn = @NO;
        builder.languageTags = @[@"en-us"];
        builder.tagSelector = [UAInAppMessageTagSelector selectorWithJSON:@{
                                @"not" : @{
                                        @"tag":@"not-tag"
                                        }
                                } error:&error];

        UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"] scope:@[@"ios",@"version"]];
        builder.versionPredicate = [UAJSONPredicate predicateWithJSONMatcher:matcher];
        builder.testDevices = @[@"test-device"];
        builder.missBehavior = UAInAppMessageAudienceMissBehaviorSkip;
    }];
    
    // test
    UAInAppMessageAudience *fromJSON = [UAInAppMessageAudience audienceWithJSON:[originalAudience toJSON] error:&error];
    
    // verify
    XCTAssertEqualObjects(originalAudience, fromJSON);
    XCTAssertEqual(originalAudience.hash, fromJSON.hash);
    XCTAssertNil(error);
}

- (void)testNotValidMissBehavior {
    //setup
    __block NSError *error;
    UAInAppMessageAudience *originalAudience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {
        builder.isNewUser = @YES;
        builder.notificationsOptIn = @YES;
        builder.locationOptIn = @NO;
        builder.languageTags = @[@"en-us"];
        builder.tagSelector = [UAInAppMessageTagSelector selectorWithJSON:@{
                                                                            @"not" : @{
                                                                                    @"tag":@"not-tag"
                                                                                    }
                                                                            } error:&error];
        
        UAJSONMatcher *matcher = [UAJSONMatcher matcherWithValueMatcher:[UAJSONValueMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"] scope:@[@"ios",@"version"]];
        builder.versionPredicate = [UAJSONPredicate predicateWithJSONMatcher:matcher];
        builder.testDevices = @[@"test-device"];
        builder.missBehavior = UAInAppMessageAudienceMissBehaviorSkip;
    }];
    
    // test
    UAInAppMessageAudience *fromJSON = [UAInAppMessageAudience audienceWithJSON:[originalAudience toJSON] error:&error];

    // verify
    XCTAssertEqualObjects(originalAudience, fromJSON);
    XCTAssertEqual(originalAudience.hash, fromJSON.hash);
    XCTAssertNil(error);

    // use not valid miss behavior
    NSMutableDictionary *audienceAsJSON = [[originalAudience toJSON] mutableCopy];
    audienceAsJSON[@"miss_behavior"] = @"bad behavior";
    UAInAppMessageAudience *badBehaviorAudience = [UAInAppMessageAudience audienceWithJSON:audienceAsJSON error:&error];
    
    // verify
    XCTAssertNil(badBehaviorAudience);
    XCTAssertNotNil(error);
}

- (void)testAudienceMissBehaviorJSONParsing {
    // setup
    __block NSError *error;
    UAInAppMessageAudience *originalAudience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder *builder) {}];
    
    NSMutableDictionary *audienceAsJSON = [[originalAudience toJSON] mutableCopy];
    
    // test
    // default
    UAInAppMessageAudience *defaultBehaviorAudience = [UAInAppMessageAudience audienceWithJSON:audienceAsJSON error:&error];
    XCTAssertEqual(defaultBehaviorAudience.missBehavior, UAInAppMessageAudienceMissBehaviorPenalize);
    XCTAssertNil(error);
    
    // cancel
    audienceAsJSON[@"miss_behavior"] = @"cancel";
    UAInAppMessageAudience *cancelBehaviorAudience = [UAInAppMessageAudience audienceWithJSON:audienceAsJSON error:&error];
    XCTAssertEqual(cancelBehaviorAudience.missBehavior, UAInAppMessageAudienceMissBehaviorCancel);
    XCTAssertNil(error);

    // cancel
    audienceAsJSON[@"miss_behavior"] = @"skip";
    UAInAppMessageAudience *skipBehaviorAudience = [UAInAppMessageAudience audienceWithJSON:audienceAsJSON error:&error];
    XCTAssertEqual(skipBehaviorAudience.missBehavior, UAInAppMessageAudienceMissBehaviorSkip);
    XCTAssertNil(error);

    // cancel
    audienceAsJSON[@"miss_behavior"] = @"penalize";
    UAInAppMessageAudience *penalizeBehaviorAudience = [UAInAppMessageAudience audienceWithJSON:audienceAsJSON error:&error];
    XCTAssertEqual(penalizeBehaviorAudience.missBehavior, UAInAppMessageAudienceMissBehaviorPenalize);
    XCTAssertNil(error);
}

@end
