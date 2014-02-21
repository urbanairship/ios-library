
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UACloseWindowAction.h"
#import "UAActionArguments.h"
#import "UALandingPageViewController.h"
#import "UAInbox.h"
#import "UAInboxUI.h"
#import "UARichContentWindow.h"

@interface UACloseWindowActionTest : XCTestCase
@property(nonatomic, strong) UACloseWindowAction *action;
@property(nonatomic, strong) id mockLPVC;
@property(nonatomic, strong) id mockUIClassRichContentWindow;
@property(nonatomic, strong) id mockUIClass;
@end

//OCMock seems not to like expecting on the protocol itself,
//this is just a dummy for the sake of expediency
@interface TestUIClassRichContentWindow : NSObject<UARichContentWindow>

+ (void)closeWindow:(BOOL)animated;

@end

@implementation TestUIClassRichContentWindow

+ (void)closeWindow:(BOOL)animated {
    //do nothing
}

@end

@implementation UACloseWindowActionTest

- (void)setUp {
    [super setUp];
    self.action = [[UACloseWindowAction alloc] init];
    self.mockLPVC = [OCMockObject niceMockForClass:[UALandingPageViewController class]];
    self.mockUIClassRichContentWindow = [OCMockObject niceMockForClass:[TestUIClassRichContentWindow class]];
    self.mockUIClass = [OCMockObject niceMockForClass:[NSObject class]];
}

- (void)tearDown {
    [self.mockLPVC stopMocking];
    [self.mockUIClass stopMocking];
    [super tearDown];
}

- (void)testAcceptsArguments {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:nil withSituation:UASituationBackgroundPush];
    BOOL accepts = [self.action acceptsArguments:args];
    XCTAssertFalse(accepts, @"close window action should not accept background push situations");
}

- (void)testPerform {
    [UAInbox useCustomUI:[TestUIClassRichContentWindow class]];

    [[self.mockLPVC expect] closeWindow:YES];
    [[self.mockUIClassRichContentWindow expect] closeWindow:YES];
    [self.action performWithArguments:[UAActionArguments argumentsWithValue:nil withSituation:UASituationManualInvocation]
                withCompletionHandler:nil];
    [self.mockLPVC verify];
    [self.mockUIClassRichContentWindow verify];

    //UI classes not impelmenting the RichContentWindow protocol should not be called
    [UAInbox useCustomUI:[NSObject class]];
    [self.action performWithArguments:[UAActionArguments argumentsWithValue:nil withSituation:UASituationManualInvocation]
                withCompletionHandler:nil];
    [self.mockUIClass verify];
}

@end
