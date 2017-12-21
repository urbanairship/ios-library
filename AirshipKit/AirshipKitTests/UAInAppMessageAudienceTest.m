/* Copyright 2017 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAVersionMatcher+Internal.h"
#import "UAInAppMessageTagSelector+Internal.h"

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
        builder.versionMatcher = [UAVersionMatcher matcherWithVersionConstraint:@"[1.0, 2.0]"];
    }];
    
    // test
    UAInAppMessageAudience *fromJSON = [UAInAppMessageAudience audienceWithJSON:[originalAudience toJSON] error:&error];
    
    // verify
    XCTAssertEqualObjects(originalAudience, fromJSON);
    XCTAssertEqual(originalAudience.hash, fromJSON.hash);
}


@end
