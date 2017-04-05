/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import "UAActionRegistryEntry.h"

@interface UAActionRegistryEntryTest : XCTestCase

@end

@implementation UAActionRegistryEntryTest

- (void)testEntryForAction {
    UAAction *action = [[UAAction alloc] init];
    UAActionPredicate predicate = ^(UAActionArguments *args) { return NO; };

    UAActionRegistryEntry *entry = [UAActionRegistryEntry entryForAction:action predicate:predicate];

    XCTAssertEqualObjects(entry.action, action, @"UAActionEntry is not setting the action correctly");
    XCTAssertEqualObjects(entry.predicate, predicate, @"UAActionEntry is not setting the predicate correctly");
}

@end
