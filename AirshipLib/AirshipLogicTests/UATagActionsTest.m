
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAAction+Internal.h"
#import "UAAddTagsAction.h"
#import "UARemoveTagsAction.h"
#import "UASetTagsAction.h"
#import "UAPush+Internal.h"
#import "UAPush+Test.h"

@interface UATagActionsTest : XCTestCase
@property(nonatomic, strong) id mockPush;
@property(nonatomic, strong) UAActionArguments *stringArgs;
@property(nonatomic, strong) UAActionArguments *arrayArgs;
@property(nonatomic, strong) UAActionArguments *emptyArrayArgs;
@property(nonatomic, strong) UAActionArguments *badArrayArgs;
@property(nonatomic, strong) UAActionArguments *numberArgs;
@end

@implementation UATagActionsTest

- (void)setUp {
    [super setUp];
    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];
    self.stringArgs = [UAActionArguments argumentsWithValue:@"hi" withSituation:nil];
    self.arrayArgs = [UAActionArguments argumentsWithValue:@[@"hi", @"there"] withSituation:nil];
    self.emptyArrayArgs = [UAActionArguments argumentsWithValue:@[] withSituation:nil];
    self.badArrayArgs = [UAActionArguments argumentsWithValue:@[@"hi", @10] withSituation:nil];
    self.numberArgs = [UAActionArguments argumentsWithValue:@10 withSituation:nil];
    [UAPush configure:self.mockPush];
}

- (void)tearDown {
    [self.mockPush stopMocking];
    [UAPush reset];
    [super tearDown];
}

/**
 * Makes sure that the passed action rejects the background situation
 */
- (void)validateSituationForTagAction:(UAAction *)action {

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@[@"hey!"] withSituation:nil];

    XCTAssertTrue([action acceptsArguments:args], @"nil situation should be acceptable");

    for (NSString *situation in @[UASituationLaunchedFromPush, UASituationForegroundPush, UASituationLaunchedFromSpringBoard, UASituationRichPushAction]) {
        args.situation = situation;
        NSLog(@"situation!: %@", args.situation);
        XCTAssertTrue([action acceptsArguments:args], @"any non-background situation should be valid");
    }

    args.situation = UASituationBackgroundPush;
    XCTAssertFalse([action acceptsArguments:args], @"background situation should be invalid");

    args.situation = nil;
}

/**
 * Add/Remove tags should accept strings, empty arrays, and arrays of strings
 */
- (void)validateArgumentsForAddRemoveTagsAction:(UAAction *)action {
    [self validateSituationForTagAction:action];

    XCTAssertTrue([action acceptsArguments:self.stringArgs], @"strings should be accepted");
    XCTAssertTrue([action acceptsArguments:self.arrayArgs], @"arrays should be accepted");
    XCTAssertTrue([action acceptsArguments:self.emptyArrayArgs], @"empty arrays should be accepted");
    XCTAssertFalse([action acceptsArguments:self.badArrayArgs], @"arrays should only contain strings");
    XCTAssertFalse([action acceptsArguments:self.numberArgs], @"non arrays/strings should be rejected");
}

/**
 * Set tags should accept empty arrays, and arrays of strings
 */
- (void)validateArgumentsForSetTagsAction:(UAAction *)action {
    [self validateSituationForTagAction:action];

    XCTAssertTrue([action acceptsArguments:self.arrayArgs], @"arrays should be accepted");
    XCTAssertTrue([action acceptsArguments:self.emptyArrayArgs], @"empty arrays should be accepted");
    XCTAssertFalse([action acceptsArguments:self.badArrayArgs], @"arrays should only contain strings");
    XCTAssertFalse([action acceptsArguments:self.stringArgs], @"strings should be rejected");
    XCTAssertFalse([action acceptsArguments:self.numberArgs], @"non arrays should be rejected");
}

/**
 * Checks argument validation and UAPush side effects of the add tags action
 */
- (void)testAddTagsAction {
    UAAddTagsAction *action = [[UAAddTagsAction alloc] init];
    [self validateArgumentsForAddRemoveTagsAction:action];

    [[self.mockPush expect] addTagToCurrentDevice:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.stringArgs
       withCompletionHandler:^(UAActionResult *result){
           [self.mockPush verify];
    }];

    [[self.mockPush expect] addTagsToCurrentDevice:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.arrayArgs
       withCompletionHandler:^(UAActionResult *result){
           [self.mockPush verify];
    }];
}

/**
 * Checks argument validation and UAPush side effects of the remove tags action
 */
- (void)testRemoveTagsAction {
    UARemoveTagsAction *action = [[UARemoveTagsAction alloc] init];
    [self validateArgumentsForAddRemoveTagsAction:action];

    [[self.mockPush expect] removeTagFromCurrentDevice:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.stringArgs
       withCompletionHandler:^(UAActionResult *result){
           [self.mockPush verify];
    }];

    [[self.mockPush expect] removeTagsFromCurrentDevice:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.arrayArgs
       withCompletionHandler:^(UAActionResult *result){
           [self.mockPush verify];
    }];

}

/**
 * Checks argument validation and UAPush side effects of the set tags action
 */
- (void)testSetTagsAction {
    UASetTagsAction *action = [[UASetTagsAction alloc] init];
    [self validateArgumentsForSetTagsAction:action];

    [[self.mockPush expect] setTags:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.arrayArgs
       withCompletionHandler:^(UAActionResult *result){
           [self.mockPush verify];
    }];
}

@end
