
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAAction+Internal.h"
#import "UAAddTagAction.h"
#import "UARemoveTagAction.h"
#import "UASetTagsAction.h"
#import "UAPush+Internal.h"

@interface UATagActionsTest : XCTestCase
@property(nonatomic, strong) id mockedDeviceAPIClient;
@end

@implementation UATagActionsTest

- (void)setUp {
    [super setUp];
    self.mockedDeviceAPIClient = [OCMockObject partialMockForObject:[UAPush shared].deviceAPIClient];
}

- (void)validateSituationForTagAction:(UAAction *)action withArgs:(id)value {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:value withSituation:nil];

    XCTAssertTrue([action acceptsArguments:args], @"no situation should be acceptable");

    for (NSString *situation in @[UASituationLaunchedFromPush, UASituationForegroundPush, UASituationLaunchedFromSpringBoard, UASituationRichPushAction]) {
        args.situation = situation;
        XCTAssertTrue([action acceptsArguments:args], @"any non-background situation should be valid");
    }

    args.situation = UASituationBackgroundPush;
    XCTAssertFalse([action acceptsArguments:args], @"background situation should be invalid");
}

- (void)validateArgumentsForSingleTagAction:(UAAction *)action {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@"hey!" withSituation:nil];
    [self validateSituationForTagAction:action withArgs:args];

    args.value = [NSNumber numberWithInt:10];
    XCTAssertFalse([action acceptsArguments:args], @"only strings are allowed as values");

    args.value = [NSArray array];
    XCTAssertFalse([action acceptsArguments:args], @"only strings are allowed as values");
}

- (void)validateArgumentsForSetTagsAction:(UAAction *)action {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:@[@"foo", @"bar", @"baz"] withSituation:nil];
    [self validateSituationForTagAction:action withArgs:args];

    args.value = [NSNumber numberWithInt:10];
    XCTAssertFalse([action acceptsArguments:args], @"only arrays are allowed as values");

    args.value = @"howdy";
    XCTAssertFalse([action acceptsArguments:args], @"only arrays are allowed as values");

    args.value = @[@"foo", [NSNumber numberWithInt:10]];
    XCTAssertFalse([action acceptsArguments:args], @"arrays must only contain strings");

    XCTAssertTrue([action acceptsArguments:args], @"empty arrays are acceptable");
    args.value = @[];
}

- (void)testAddTagAction {
    UAAddTagAction *action = [[UAAddTagAction alloc] init];
    [self validateArgumentsForSingleTagAction:action];

    [action runWithArguments:
     [UAActionArguments argumentsWithValue:@"hi" withSituation:nil]
       withCompletionHandler:^(UAActionResult *result){
           NSSet *set = [NSSet setWithArray:[UAPush shared].tags];
           XCTAssertTrue([set isEqualToSet:[NSSet setWithArray:@[@"hi"]]], @"tags should contain 'hi'");
       }];

    [action runWithArguments:
     [UAActionArguments argumentsWithValue:@"there" withSituation:nil]
       withCompletionHandler:^(UAActionResult *result){
           NSSet *set = [NSSet setWithArray:[UAPush shared].tags];
           XCTAssertTrue([set isEqualToSet:[NSSet setWithArray:@[@"hi", @"there"]]], @"tags should contain 'hi', 'there'");
       }];

    //test run
}

- (void)testRemoveTagAction {
    UARemoveTagAction *action = [[UARemoveTagAction alloc] init];
    [self validateArgumentsForSingleTagAction:action];

    //test run
}

- (void)testSetTagsAction {
    UASetTagsAction *action = [[UASetTagsAction alloc] init];
    [self validateArgumentsForSetTagsAction:action];

    //test run
}

- (void)tearDown {
    [UAPush shared].tags = nil;
    [super tearDown];
}

@end
