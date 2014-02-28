
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UALandingPageAction.h"
#import "UAURLProtocol.h"
#import "UALandingPageViewController.h"

@interface UALandingPageActionTest : XCTestCase

@property(nonatomic, strong) id mockURLProtocol;
@property(nonatomic, strong) id mockLandingPageViewController;
@property(nonatomic, strong) UALandingPageAction *action;

@end

@implementation UALandingPageActionTest

- (void)setUp {
    [super setUp];
    self.action = [[UALandingPageAction alloc] init];
    self.mockURLProtocol = [OCMockObject niceMockForClass:[UAURLProtocol class]];
    self.mockLandingPageViewController = [OCMockObject niceMockForClass:[UALandingPageViewController class]];
}

- (void)tearDown {
    [self.mockLandingPageViewController stopMocking];
    [self.mockURLProtocol stopMocking];
    [super tearDown];
}

- (void)testAcceptsArguments {
    NSArray *acceptedSituations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                                    [NSNumber numberWithInteger:UASituationForegroundPush],
                                    [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                                    [NSNumber numberWithInteger:UASituationLaunchedFromSpringBoard],
                                    [NSNumber numberWithInteger:UASituationManualInvocation]];

    NSArray *acceptedValues= @[@"https://foo.bar.com/whatever",
                               [NSURL URLWithString:@"https://foo.bar.com/whatever"]];

    for (NSNumber *situationNumber in acceptedSituations) {
        for (id value in acceptedValues) {
            UAActionArguments *args = [UAActionArguments argumentsWithValue:value
                                                              withSituation:[situationNumber integerValue]];
            BOOL accepts = [self.action acceptsArguments:args];
            NSLog(@"value: %@", value);
            NSLog(@"situation %@", situationNumber);
            XCTAssertTrue(accepts, @"landing page action should accept situation %@, value %@", situationNumber, value);
        }
    }
}

- (void)testPerform {

}

@end
