/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UABaseTest.h"

#import "UAActionArguments+Internal.h"
#import "UAActionResult.h"

@import AirshipCore;

@interface UAPasteboardActionTest : UABaseTest
@property(nonatomic, strong) UAPasteboardAction *action;
@property(nonatomic, strong) id mockPasteboard;
@end

@implementation UAPasteboardActionTest

- (void)setUp {
    [super setUp];

    self.mockPasteboard = [self mockForClass:[UIPasteboard class]];
    [[[self.mockPasteboard stub] andReturn:self.mockPasteboard] generalPasteboard];

    self.action = [UAPasteboardAction new];
}

/**
 * Test accepts valid string arguments in foreground situations.
 */
- (void)testAcceptsArguments {
    UASituation validSituations[6] = {
        UASituationForegroundInteractiveButton,
        UASituationBackgroundInteractiveButton,
        UASituationLaunchedFromPush,
        UASituationManualInvocation,
        UASituationWebViewInvocation,
        UASituationAutomation
    };

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationBackgroundInteractiveButton;


    // Should accept an NSString
    arguments.value = @"pasteboard string";
    for (int i = 0; i < 6; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }

    // Should accept an NSDictionary with "text" 
    arguments.value = @{ @"text": @"pasteboard string"};
    for (int i = 0; i < 6; i++) {
        arguments.situation = validSituations[i];
        XCTAssertTrue([self.action acceptsArguments:arguments], @"action should accept situation %zd", validSituations[i]);
    }
}

/**
 * Test perform with a string sets the pasteboard's string
 */
- (void)testPerformWithString {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = @"pasteboard string";

    [[self.mockPasteboard expect] setString:@"pasteboard string"];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqualObjects(arguments.value, result.value);
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockPasteboard verify];
}

/**
 * Test perform with a dictionary sets the pasteboard's string
 */
- (void)testPerformWithDictionary {
    __block BOOL actionPerformed = NO;

    UAActionArguments *arguments = [[UAActionArguments alloc] init];
    arguments.situation = UASituationManualInvocation;
    arguments.value = @{@"text":  @"pasteboard string"};

    [[self.mockPasteboard expect] setString:@"pasteboard string"];

    [self.action performWithArguments:arguments completionHandler:^(UAActionResult *result) {
        actionPerformed = YES;
        XCTAssertEqualObjects(arguments.value, result.value);
    }];

    XCTAssertTrue(actionPerformed);
    [self.mockPasteboard verify];
}

@end
