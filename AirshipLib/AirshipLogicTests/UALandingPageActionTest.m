
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UALandingPageAction.h"
#import "UAURLProtocol.h"
#import "UALandingPageViewController.h"
#import "UAAction+Internal.h"

@interface UALandingPageActionTest : XCTestCase

@property(nonatomic, strong) id mockURLProtocol;
@property(nonatomic, strong) id mockLandingPageViewController;
@property(nonatomic, strong) UALandingPageAction *action;
@property(nonatomic, strong) NSString *urlString;

@end

@implementation UALandingPageActionTest

- (void)setUp {
    [super setUp];
    self.action = [[UALandingPageAction alloc] init];
    self.mockURLProtocol = [OCMockObject niceMockForClass:[UAURLProtocol class]];
    self.mockLandingPageViewController = [OCMockObject niceMockForClass:[UALandingPageViewController class]];
    self.urlString = @"https://foo.bar.com/whatever";
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


    NSArray *acceptedValues= @[self.urlString, [NSURL URLWithString:self.urlString]];

    for (NSNumber *situationNumber in acceptedSituations) {
        for (id value in acceptedValues) {
            UAActionArguments *args = [UAActionArguments argumentsWithValue:value
                                                              withSituation:[situationNumber integerValue]];
            BOOL accepts = [self.action acceptsArguments:args];
            XCTAssertTrue(accepts, @"landing page action should accept situation %@, value %@", situationNumber, value);
        }
    }
}

- (void)performWithValue:(id)value {

    __block BOOL finished = NO;

    UAActionArguments *args = [UAActionArguments argumentsWithValue:value withSituation:UASituationManualInvocation];

    [[self.mockURLProtocol expect] addCachableURL:[OCMArg checkWithBlock:^(id obj){
        return (BOOL)([obj isKindOfClass:[NSURL class]] && [((NSURL *)obj).scheme isEqualToString:@"https"]);
    }]];

    [[self.mockLandingPageViewController expect] closeWindow:NO];

    [[self.mockLandingPageViewController expect] showURL:[OCMArg checkWithBlock:^(id obj){
        return (BOOL)([obj isKindOfClass:[NSURL class]] && [((NSURL *)obj).scheme isEqualToString:@"https"]);
    }]];

    [self.action performWithArguments:args withCompletionHandler:^(UAActionResult *result){
        finished = YES;
        XCTAssertEqual(result.fetchResult, UAActionFetchResultNewData, @"fetch result should show new data");
    }];

    [self.mockURLProtocol verify];
    [self.mockLandingPageViewController verify];

    XCTAssertTrue(finished, @"action should have completed");
}

- (void)testPerformWithString {
    [self performWithValue:self.urlString];
}

- (void)testPerformWithUrl {
    [self performWithValue:[NSURL URLWithString:self.urlString]];
}

- (void)testPerformWithSchemelessURL {
    [self performWithValue:@"foo.bar.com/whatever"];
}

@end
