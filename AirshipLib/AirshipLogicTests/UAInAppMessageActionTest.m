
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "UAInAppMessageAction.h"
#import "UAActionArguments+Internal.h"

@interface UAInAppMessageActionTest : XCTestCase
@property(nonatomic, strong) NSDictionary *payload;
@property(nonatomic, strong) UAInAppMessageAction *action;
@property(nonatomic, strong) UAActionArguments *arguments;
@end

@implementation UAInAppMessageActionTest

- (void)setUp {
    [super setUp];
    self.action = [UAInAppMessageAction new];

    id expiry = @"2020-12-15T11:45:22";
    id extra = @{@"foo":@"bar", @"baz":@12345};
    id display = @{@"alert":@"hi!", @"type":@"banner", @"duration":@20, @"position":@"top", @"primary_color":@"#ffffffff", @"secondary_color":@"#ff00ff00"};
    id actions = @{@"on_click":@{@"^d":@"http://google.com"}, @"button_group":@"ua_yes_no_foreground", @"button_actions":@{@"yes":@{@"^+t": @"yes_tag"}, @"no":@{@"^+t": @"no_tag"}}};

    self.payload = @{@"identifier":@"some identifier", @"expiry":expiry, @"extra":extra, @"display":display, @"actions":actions};

    self.arguments = [UAActionArguments argumentsWithValue:self.payload withSituation:UASituationManualInvocation];
}

- (void)tearDown {
    //teardown
    [super tearDown];
}

/**
 * Test that action accepts NSDictionary arguments in non-launched from push situations
 */
- (void)testAcceptsArguments {

    UASituation validSituations[6] = {
        UASituationForegroundPush,
        UASituationBackgroundPush,
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton,
        UASituationManualInvocation,
        UASituationWebViewInvocation
    };

    for (int i = 0; i < 6; i++) {
        self.arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:self.arguments], @"action should accept NSDictionary values and non-launch from push situations");
    }
}

/**
 * Test that action rejects background situations.
 */
- (void)testAcceptsArgumentsRejectsLaunchedFromPushSituation {
    self.arguments.situation = UASituationLaunchedFromPush;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject situation UASituationLaunchedFromPush");
}

/**
 * Test that action rejects argument values that are not dictionaries.
 */
- (void)testAcceptsArgumentsRejectsNonDictionaries {
    self.arguments.value = nil;
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject a nil value");

    self.arguments.value = @"not a dictionary";
    XCTAssertFalse([self.action acceptsArguments:self.arguments], @"action should reject non-dictionary values");
}


@end
