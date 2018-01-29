/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageTagSelector+Internal.h"

@interface UAInAppMessageTagSelectorTest : UABaseTest

@property (nonatomic, strong) UAInAppMessageTagSelector *selector;
@end

@implementation UAInAppMessageTagSelectorTest

- (void)setUp {
    [super setUp];
    self.selector = [UAInAppMessageTagSelector or:@[
                        [UAInAppMessageTagSelector and:@[
                            [UAInAppMessageTagSelector tag:@"some-tag"],
                            [UAInAppMessageTagSelector not:[UAInAppMessageTagSelector tag:@"not-tag"]]
                            ]
                        ],
                        [UAInAppMessageTagSelector tag:@"some-other-tag"]
                        ]
                    ];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testJSON {
    NSError *error;
    UAInAppMessageTagSelector *toAndFromJson = [UAInAppMessageTagSelector selectorWithJSON:[self.selector toJSON] error:&error];
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
