/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAActionRegistryEntry.h"
#import "UALandingPageAction.h"

@interface UAActionRegistryEntryTest : UABaseTest

@end

@implementation UAActionRegistryEntryTest

- (void)testEntryForAction {
    UAAction *action = [[UAAction alloc] init];
    UAActionPredicate predicate = ^(UAActionArguments *args) { return NO; };

    UAActionRegistryEntry *entry = [UAActionRegistryEntry entryForAction:action predicate:predicate];

    XCTAssertEqualObjects(entry.action, action, @"UAActionEntry is not setting the action correctly");
    XCTAssertEqualObjects(entry.predicate, predicate, @"UAActionEntry is not setting the predicate correctly");
}

- (void)testEntryForActionClass {
    UAActionPredicate predicate = ^(UAActionArguments *args) { return NO; };

    UAActionRegistryEntry *entry = [UAActionRegistryEntry entryForActionClass:[UALandingPageAction class] predicate:predicate];

    XCTAssertNotNil(entry.action, @"UAActionEntry is not lazy loading the action correctly when set via action class");
    XCTAssertEqualObjects(entry.predicate, predicate, @"UAActionEntry is not setting the predicate correctly");
}

@end
