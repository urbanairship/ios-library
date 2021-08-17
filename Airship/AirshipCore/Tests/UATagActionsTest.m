/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAActionArguments+Internal.h"
#import "UAirship+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UATagActionsTest : UABaseTest
@property (nonatomic, strong) UATestContact *testContact;
@property (nonatomic, strong) UATestChannel *testChannel;

@property (nonatomic, strong) UAActionArguments *stringArgs;
@property (nonatomic, strong) UAActionArguments *arrayArgs;
@property (nonatomic, strong) UAActionArguments *emptyArrayArgs;
@property (nonatomic, strong) UAActionArguments *badArrayArgs;
@property (nonatomic, strong) UAActionArguments *numberArgs;
@property (nonatomic, strong) UAActionArguments *dictArgs;
@property (nonatomic, strong) UAActionArguments *dictIntKeysArgs;
@property (nonatomic, strong) UAActionArguments *dictIntValuesArgs;
@end

@implementation UATagActionsTest

- (void)setUp {
    [super setUp];
    self.testChannel = [[UATestChannel alloc] init];
    self.testContact = [[UATestContact alloc] init];

    self.stringArgs = [UAActionArguments argumentsWithValue:@"hi" withSituation:UASituationWebViewInvocation];
    self.arrayArgs = [UAActionArguments argumentsWithValue:@[@"hi", @"there"] withSituation:UASituationManualInvocation];
    self.emptyArrayArgs = [UAActionArguments argumentsWithValue:@[] withSituation:UASituationForegroundPush];
    self.badArrayArgs = [UAActionArguments argumentsWithValue:@[@"hi", @10] withSituation:UASituationLaunchedFromPush];
    self.numberArgs = [UAActionArguments argumentsWithValue:@10 withSituation:UASituationWebViewInvocation];

    NSDictionary *channelDict = @{@"group1" : @[@"tag1", @"tag2"],@"group2" : @[@"tag3", @"tag4"]};
    NSDictionary *namedUserDict = @{@"group3" : @[@"tag5", @"tag6"]};
    NSDictionary *dict = @{@"channel" : channelDict, @"named_user" : namedUserDict, @"device": @[@"device tag", @"another device tag"]};
    self.dictArgs = [UAActionArguments argumentsWithValue:dict withSituation:UASituationWebViewInvocation];

    NSDictionary *dictIntKeys = @{@1 : channelDict, @2 : namedUserDict};
    self.dictIntKeysArgs = [UAActionArguments argumentsWithValue:dictIntKeys withSituation:UASituationWebViewInvocation];
    
    NSDictionary *dictIntValues = @{@"channel" : @1, @"named_user" : @2};
    self.dictIntValuesArgs = [UAActionArguments argumentsWithValue:dictIntValues withSituation:UASituationWebViewInvocation];
}

/**
 * Makes sure that the passed action rejects the background situation
 */
- (void)validateSituationForTagAction:(id<UAAction>)action {
    UASituation situations[6] = {
        UASituationLaunchedFromPush,
        UASituationForegroundPush,
        UASituationWebViewInvocation,
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton,
        UASituationAutomation
    };

    UAActionArguments *args = [UAActionArguments argumentsWithValue:@[@"hey!"] withSituation:UASituationLaunchedFromPush];

    XCTAssertTrue([action acceptsArguments:args], @"nil situation should be acceptable");


    for (NSInteger i = 0; i < 6; i++) {
        args.situation = situations[i];
        XCTAssertTrue([action acceptsArguments:args], @"any non-background situation should be valid");
    }

    args.situation = UASituationBackgroundPush;
    XCTAssertFalse([action acceptsArguments:args], @"background situation should be invalid");

    args.situation = UASituationLaunchedFromPush;
}

/**
 * Add/Remove tags should accept strings, empty arrays, and arrays of strings
 */
- (void)validateArgumentsForAddRemoveTagsAction:(id<UAAction>)action {
    [self validateSituationForTagAction:action];

    XCTAssertTrue([action acceptsArguments:self.stringArgs], @"strings should be accepted");
    XCTAssertTrue([action acceptsArguments:self.arrayArgs], @"arrays should be accepted");
    XCTAssertTrue([action acceptsArguments:self.emptyArrayArgs], @"empty arrays should be accepted");
    XCTAssertFalse([action acceptsArguments:self.badArrayArgs], @"arrays should only contain strings");
    XCTAssertFalse([action acceptsArguments:self.numberArgs], @"non arrays/strings should be rejected");
    XCTAssertTrue([action acceptsArguments:self.dictArgs], @"dictionaries should be accepted");
    XCTAssertFalse([action acceptsArguments:self.dictIntValuesArgs], @"dictionaries with non-array values should not be accepted");
    XCTAssertFalse([action acceptsArguments:self.dictIntKeysArgs], @"dictionaries with non-string keys should not be accepted");
}

/**
 * Set tags should accept empty arrays, and arrays of strings
 */
- (void)validateArgumentsForSetTagsAction:(id<UAAction>)action {
    [self validateSituationForTagAction:action];

    XCTAssertTrue([action acceptsArguments:self.arrayArgs], @"arrays should be accepted");
    XCTAssertTrue([action acceptsArguments:self.emptyArrayArgs], @"empty arrays should be accepted");
    XCTAssertFalse([action acceptsArguments:self.badArrayArgs], @"arrays should only contain strings");
    XCTAssertFalse([action acceptsArguments:self.stringArgs], @"strings should be rejected");
    XCTAssertFalse([action acceptsArguments:self.numberArgs], @"non arrays should be rejected");
    XCTAssertTrue([action acceptsArguments:self.dictArgs], @"dictionaries should be accepted");
    XCTAssertFalse([action acceptsArguments:self.dictIntValuesArgs], @"dictionaries with non-array values should not be accepted");
    XCTAssertFalse([action acceptsArguments:self.dictIntKeysArgs], @"dictionaries with non-string keys should not be accepted");}

/**
 * Checks argument validation and UAPush side effects of the add tags action
 */
- (void)testAddTagsAction {
    UAAddTagsAction *action = [[UAAddTagsAction alloc] initWithChannel:^{
        return self.testChannel;
    } contact:^{
        return self.testContact;
    }];
    [self validateArgumentsForAddRemoveTagsAction:action];

    [action performWithArguments:self.stringArgs completionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(self.testChannel.tags, @[self.stringArgs.value]);
    }];

    self.testChannel.tags = @[];
    [action performWithArguments:self.arrayArgs completionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(self.testChannel.tags, self.arrayArgs.value);
    }];
    
    __block NSArray *channelTagUpdates;
    self.testChannel.tagGroupEditor = [[UATagGroupsEditor alloc] initWithAllowDeviceTagGroup:YES completionHandler:^(NSArray<UATagGroupUpdate *> *updates) {
        channelTagUpdates = updates;
    }];
     
    __block NSArray *contactTagUpdates;
    self.testContact.tagGroupEditor = [[UATagGroupsEditor alloc] initWithAllowDeviceTagGroup:YES completionHandler:^(NSArray<UATagGroupUpdate *> *updates) {
        contactTagUpdates = updates;
    }];

    self.testChannel.tags = @[];
    [action performWithArguments:self.dictArgs completionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(self.dictArgs.value[@"named_user"], [self tagsFromUpdates:contactTagUpdates]);
        XCTAssertEqualObjects(self.dictArgs.value[@"channel"], [self tagsFromUpdates:channelTagUpdates]);
        
        XCTAssertEqualObjects(self.dictArgs.value[@"device"], self.testChannel.tags);
    }];
}

/**
 * Checks argument validation and UAPush side effects of the remove tags action
 */
- (void)testRemoveTagsAction {
    UARemoveTagsAction *action = [[UARemoveTagsAction alloc] initWithChannel:^{
        return self.testChannel;
    } contact:^{
        return self.testContact;
    }];
    
    [self validateArgumentsForAddRemoveTagsAction:action];
    
    self.testChannel.tags = @[@"hi", @"cool"];

    [action performWithArguments:self.stringArgs completionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(@[@"cool"], self.testChannel.tags);
    }];
    self.testChannel.tags = @[@"hi", @"there"];

    [action performWithArguments:self.arrayArgs completionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(@[], self.testChannel.tags);
    }];

    __block NSArray *channelTagUpdates;
    self.testChannel.tagGroupEditor = [[UATagGroupsEditor alloc] initWithAllowDeviceTagGroup:YES completionHandler:^(NSArray<UATagGroupUpdate *> *updates) {
        channelTagUpdates = updates;
    }];

    __block NSArray *contactTagUpdates;
    self.testContact.tagGroupEditor = [[UATagGroupsEditor alloc] initWithAllowDeviceTagGroup:YES completionHandler:^(NSArray<UATagGroupUpdate *> *updates) {
        contactTagUpdates = updates;
    }];

    [action performWithArguments:self.dictArgs completionHandler:^(UAActionResult *result) {
        XCTAssertEqualObjects(self.dictArgs.value[@"named_user"], [self tagsFromUpdates:contactTagUpdates]);
        XCTAssertEqualObjects(self.dictArgs.value[@"channel"], [self tagsFromUpdates:channelTagUpdates]);
    }];
}

- (NSDictionary *)tagsFromUpdates:(NSArray *)tagGroupUpdates {
    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
    
    for (UATagGroupUpdate *update in tagGroupUpdates) {
        [tags setValue:update.tags forKey:update.group];
    }
    
    return tags;
}

@end
