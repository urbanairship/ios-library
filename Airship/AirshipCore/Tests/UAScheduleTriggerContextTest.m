/* Copyright Airship and Contributors */

#import "UAScheduleTriggerContext+Internal.h"
#import "UABaseTest.h"
#import "UAScheduleTrigger.h"

@interface UAScheduleTriggerContextTest : UABaseTest

@end

@implementation UAScheduleTriggerContextTest


- (void)testEqualsNilEvent {
    UAScheduleTrigger *trigger = [UAScheduleTrigger screenTriggerForScreenName:@"some-screen" count:100];
    UAScheduleTriggerContext *original = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:nil];
    UAScheduleTriggerContext *same = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:nil];
    UAScheduleTriggerContext *different = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:@"whatever"];

    XCTAssertEqualObjects(original, same);
    XCTAssertEqualObjects(same, original);

    XCTAssertNotEqualObjects(different, original);
    XCTAssertNotEqualObjects(original, different);
}

- (void)testCodingDictionaryEvent {
    UAScheduleTrigger *trigger = [UAScheduleTrigger screenTriggerForScreenName:@"some-screen" count:100];
    id event = @{@"neat": @"story"};
    UAScheduleTriggerContext *context = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];
    [self verifyCodingForContext:context];
}

- (void)testCondingStringEvent {
    UAScheduleTrigger *trigger = [UAScheduleTrigger screenTriggerForScreenName:@"some-screen" count:100];
    UAScheduleTriggerContext *context = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:@"string"];
    [self verifyCodingForContext:context];
}

- (void)testCodingNumberEvent {
    UAScheduleTrigger *trigger = [UAScheduleTrigger screenTriggerForScreenName:@"some-screen" count:100];
    UAScheduleTriggerContext *context = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:@(100)];
    [self verifyCodingForContext:context];
}

- (void)testCodingNilEvent {
    UAScheduleTrigger *trigger = [UAScheduleTrigger screenTriggerForScreenName:@"some-screen" count:100];
    UAScheduleTriggerContext *context = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:nil];

    [self verifyCodingForContext:context];
}

- (void)verifyCodingForContext:(UAScheduleTriggerContext *)context {
    NSError *error = nil;
    id encoded = [NSKeyedArchiver archivedDataWithRootObject:context
                                       requiringSecureCoding:YES
                                                       error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(encoded);

    id decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[UAScheduleTriggerContext class]
                                                   fromData:encoded
                                                      error:&error];

    XCTAssertNil(error);
    XCTAssertNotNil(decoded);
    XCTAssertEqualObjects(context, decoded);
}

@end
