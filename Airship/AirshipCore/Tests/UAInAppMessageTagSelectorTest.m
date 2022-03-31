/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UATagSelector+Internal.h"

@interface UATagSelectorTest : UABaseTest

@property (nonatomic, strong) UATagSelector *selector;
@property (nonatomic, strong) UATagSelector *selectorWithTagGroups;
@end

@implementation UATagSelectorTest

- (void)setUp {
    [super setUp];
    self.selector = [UATagSelector or:@[[UATagSelector and:@[[UATagSelector tag:@"some-tag"],
                                                                                     [UATagSelector not:[UATagSelector tag:@"not-tag"]]]],
                                                    [UATagSelector tag:@"some-other-tag"]]];

    self.selectorWithTagGroups = [UATagSelector and:@[[UATagSelector tag:@"some-tag"],
                                                                  [UATagSelector tag:@"some-tag"],
                                                                  [UATagSelector not:[UATagSelector tag:@"not-tag"]]]];
}

- (void)testJSON {
    NSError *error;
    UATagSelector *toAndFromJson = [UATagSelector selectorWithJSON:[self.selector toJSON] error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(self.selector, toAndFromJson);
}

- (void)testSelector {
    NSMutableArray<NSString *> *tags = [NSMutableArray array];

    // Empty list
    XCTAssertFalse([self.selector apply:tags]);
    
    [tags addObject:@"some-tag"];
    
    // Contains "some-tag" and not "not-tag"
    XCTAssertTrue([self.selector apply:tags]);

    [tags addObject:@"not-tag"];

    // Contains "some-tag" and "not-tag"
    XCTAssertFalse([self.selector apply:tags]);

    [tags addObject:@"some-other-tag"];

    // Contains "some-other-tag"
    XCTAssertTrue([self.selector apply:tags]);
}

@end
