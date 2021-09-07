/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAScheduleTrigger+Internal.h"

@import AirshipCore;

@interface UAScheduleTriggerTests : UABaseTest

@end

@implementation UAScheduleTriggerTests

- (void)testWithJSON {

    NSDictionary *predicateJSON = @{ @"and": @[ @{ @"value": @{ @"equals": @"bar" }, @"key": @"foo" },
                                       @{ @"value": @{ @"equals": @"story" }, @"key": @"cool" } ]};

    NSDictionary *triggerTypeMap = @{ UAScheduleTriggerAppForegroundName: @(UAScheduleTriggerAppForeground),
                                      UAScheduleTriggerAppBackgroundName: @(UAScheduleTriggerAppBackground),
                                      UAScheduleTriggerRegionEnterName: @(UAScheduleTriggerRegionEnter),
                                      UAScheduleTriggerRegionExitName: @(UAScheduleTriggerRegionExit),
                                      UAScheduleTriggerCustomEventCountName: @(UAScheduleTriggerCustomEventCount),
                                      UAScheduleTriggerCustomEventValueName: @(UAScheduleTriggerCustomEventValue),
                                      UAScheduleTriggerScreenName: @(UAScheduleTriggerScreen),
                                      UAScheduleTriggerAppInitName: @(UAScheduleTriggerAppInit),
                                      UAScheduleTriggerActiveSessionName : @(UAScheduleTriggerActiveSession),
                                      UAScheduleTriggerVersionName : @(UAScheduleTriggerVersion)
                                      };


    for (NSString *typeName in triggerTypeMap) {
        NSDictionary *triggerJSON = @{ UAScheduleTriggerGoalKey: @(1),
                                       UAScheduleTriggerPredicateKey: predicateJSON,
                                       UAScheduleTriggerTypeKey: typeName };

        NSError *error = nil;
        UAScheduleTrigger *trigger = [UAScheduleTrigger triggerWithJSON:triggerJSON error:&error];
        XCTAssertEqual(trigger.type, [triggerTypeMap[typeName] unsignedIntegerValue]);
        XCTAssertEqualObjects(trigger.goal, @(1));
        XCTAssertEqualObjects(trigger.predicate.payload, predicateJSON);
        XCTAssertNil(error);
    }
}

- (void)testInvalidJSON {
    NSArray *invalidValues = @[ // Missing type
                                @{UAScheduleTriggerGoalKey: @(1)},

                                // Missing goal
                                @{UAScheduleTriggerTypeKey: UAScheduleTriggerAppBackgroundName},

                                // Invalid goal
                                @{UAScheduleTriggerTypeKey: UAScheduleTriggerAppBackgroundName, UAScheduleTriggerGoalKey: @"what"},

                                // Invalid type
                                @{UAScheduleTriggerTypeKey: @"what", UAScheduleTriggerGoalKey: @(1)},

                                //Invalid predicate
                                @{UAScheduleTriggerTypeKey: UAScheduleTriggerAppBackgroundName, UAScheduleTriggerGoalKey: @(1), UAScheduleTriggerPredicateKey: @"what"},

                                // Invalid object
                                @"what" ];


    for (id value in invalidValues) {
        NSError *error;
        XCTAssertNil([UAScheduleTrigger triggerWithJSON:value error:&error]);
        XCTAssertNotNil(error);
    }
}

- (void)testCoding {
    UAScheduleTrigger *trigger = [UAScheduleTrigger screenTriggerForScreenName:@"some-screen" count:100];

    NSError *error = nil;
    id encoded = [NSKeyedArchiver archivedDataWithRootObject:trigger
                                      requiringSecureCoding:YES
                                                      error:&error];


    XCTAssertNil(error);
    XCTAssertNotNil(encoded);

    id decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[UAScheduleTrigger class]
                                                  fromData:encoded
                                                     error:&error];


    XCTAssertNil(error);
    XCTAssertNotNil(decoded);

    XCTAssertEqualObjects(trigger, decoded);
}

@end
