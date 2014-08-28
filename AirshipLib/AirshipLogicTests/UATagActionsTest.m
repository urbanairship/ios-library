
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAAction+Internal.h"
#import "UAAddTagsAction.h"
#import "UARemoveTagsAction.h"
#import "UAPush+Internal.h"
#import "UAPush+Test.h"
#import "UAActionArguments+Internal.h"

@interface UATagActionsTest : XCTestCase
@property (nonatomic, strong) id mockPush;
@property (nonatomic, strong) UAActionArguments *stringArgs;
@property (nonatomic, strong) UAActionArguments *arrayArgs;
@property (nonatomic, strong) UAActionArguments *emptyArrayArgs;
@property (nonatomic, strong) UAActionArguments *badArrayArgs;
@property (nonatomic, strong) UAActionArguments *numberArgs;
@end

@implementation UATagActionsTest

- (void)setUp {
    [super setUp];
    self.mockPush = [OCMockObject niceMockForClass:[UAPush class]];
    self.stringArgs = [UAActionArguments argumentsWithValue:@"hi" withSituation:UASituationWebViewInvocation];
    self.arrayArgs = [UAActionArguments argumentsWithValue:@[@"hi", @"there"] withSituation:UASituationManualInvocation];
    self.emptyArrayArgs = [UAActionArguments argumentsWithValue:@[] withSituation:UASituationForegroundPush];
    self.badArrayArgs = [UAActionArguments argumentsWithValue:@[@"hi", @10] withSituation:UASituationLaunchedFromPush];
    self.numberArgs = [UAActionArguments argumentsWithValue:@10 withSituation:UASituationWebViewInvocation];
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
    UASituation situations[4] = {
        UASituationLaunchedFromPush,
        UASituationForegroundPush,
        UASituationWebViewInvocation
    };

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@[@"hey!"] withSituation:UASituationLaunchedFromPush];

    XCTAssertTrue([action acceptsArguments:args], @"nil situation should be acceptable");


    for (NSInteger i = 0; i < 4; i++) {
        args.situation = situations[i];
        NSLog(@"situation!: %ld", args.situation);
        XCTAssertTrue([action acceptsArguments:args], @"any non-background situation should be valid");
    }

    args.situation = UASituationBackgroundPush;
    XCTAssertFalse([action acceptsArguments:args], @"background situation should be invalid");

    args.situation = UASituationLaunchedFromPush;
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
    NSString *actionName = @"test_action";
    [self validateArgumentsForAddRemoveTagsAction:action];

    [[self.mockPush expect] addTagToCurrentDevice:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.stringArgs
                  actionName:actionName
           completionHandler:^(UAActionResult *result) {
           [self.mockPush verify];
    }];

    [[self.mockPush expect] addTagsToCurrentDevice:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.arrayArgs actionName:actionName
       completionHandler:^(UAActionResult *result) {
           [self.mockPush verify];
    }];
}

/**
 * Checks argument validation and UAPush side effects of the remove tags action
 */
- (void)testRemoveTagsAction {
    UARemoveTagsAction *action = [[UARemoveTagsAction alloc] init];
    NSString *actionName = @"test_action";

    [self validateArgumentsForAddRemoveTagsAction:action];

    [[self.mockPush expect] removeTagFromCurrentDevice:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.stringArgs
                  actionName:actionName
           completionHandler:^(UAActionResult *result) {
           [self.mockPush verify];
    }];

    [[self.mockPush expect] removeTagsFromCurrentDevice:[OCMArg any]];
    [[self.mockPush expect] updateRegistration];

    [action runWithArguments:self.arrayArgs
                  actionName:actionName
           completionHandler:^(UAActionResult *result) {
           [self.mockPush verify];
    }];

}

@end
