
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UALandingPageAction.h"
#import "UAURLProtocol.h"
#import "UAHTTPConnection.h"
#import "UALandingPageViewController.h"
#import "UAAction+Internal.h"

@interface UALandingPageActionTest : XCTestCase

@property(nonatomic, strong) id mockURLProtocol;
@property(nonatomic, strong) id mockLandingPageViewController;
@property(nonatomic, strong) id mockHTTPConnection;
@property(nonatomic, strong) UALandingPageAction *action;
@property(nonatomic, strong) NSString *urlString;

@end

@implementation UALandingPageActionTest

- (void)setUp {
    [super setUp];
    self.action = [[UALandingPageAction alloc] init];
    self.mockURLProtocol = [OCMockObject niceMockForClass:[UAURLProtocol class]];
    self.mockLandingPageViewController = [OCMockObject niceMockForClass:[UALandingPageViewController class]];
    self.mockHTTPConnection = [OCMockObject niceMockForClass:[UAHTTPConnection class]];
    self.urlString = @"https://foo.bar.com/whatever";
}

- (void)tearDown {
    [self.mockLandingPageViewController stopMocking];
    [self.mockURLProtocol stopMocking];
    [self.mockHTTPConnection stopMocking];
    [super tearDown];
}

- (void)testAcceptsArguments {
    NSArray *acceptedSituations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                                    [NSNumber numberWithInteger:UASituationForegroundPush],
                                    [NSNumber numberWithInteger:UASituationLaunchedFromPush],
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

- (void)performWithArgs:(UAActionArguments *)args withExpectedFetchResult:(UAActionFetchResult)fetchResult {

    __block BOOL finished = NO;

    [[self.mockURLProtocol expect] addCachableURL:[OCMArg checkWithBlock:^(id obj){
        return (BOOL)([obj isKindOfClass:[NSURL class]] && [((NSURL *)obj).scheme isEqualToString:@"https"]);
    }]];
    
    [self.action performWithArguments:args withCompletionHandler:^(UAActionResult *result){
        finished = YES;
        XCTAssertEqual(result.fetchResult, fetchResult,
                       @"fetch result %ud should match expect result %ud", result.fetchResult, fetchResult);
    }];

    [self.mockURLProtocol verify];
    [self.mockLandingPageViewController verify];
    [self.mockHTTPConnection verify];

    XCTAssertTrue(finished, @"action should have completed");
}

- (void)performInForegroundWithValue:(id)value {
    [[self.mockLandingPageViewController expect] closeWindow:NO];

    [[self.mockLandingPageViewController expect] showURL:[OCMArg checkWithBlock:^(id obj){
        return (BOOL)([obj isKindOfClass:[NSURL class]] && [((NSURL *)obj).scheme isEqualToString:@"https"]);
    }]];

    [self performWithArgs:[UAActionArguments argumentsWithValue:value withSituation:UASituationManualInvocation] withExpectedFetchResult:UAActionFetchResultNewData];
}

- (void)performInBackground:(BOOL)successful {
    UAActionArguments *args = [UAActionArguments argumentsWithValue:self.urlString withSituation:UASituationBackgroundPush];

    __block UAHTTPConnectionSuccessBlock success;
    __block UAHTTPConnectionFailureBlock failure;
    __block UAHTTPRequest *request;

    [[[self.mockHTTPConnection stub] andReturn:self.mockHTTPConnection]
     connectionWithRequest:[OCMArg checkWithBlock:^(id obj){
        request = obj;
        return YES;
    }] successBlock:[OCMArg checkWithBlock:^(id obj){
        success = obj;
        return YES;
    }] failureBlock:[OCMArg checkWithBlock:^(id obj){
        failure = obj;
        return YES;
    }]];

    [(UAHTTPConnection *)[[self.mockHTTPConnection expect] andDo:^(NSInvocation *inv){
        if (successful) {
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.url
                                                                      statusCode:200
                                                                     HTTPVersion:nil
                                                                    headerFields:nil];
            [request setValue:response forKey:@"response"];
            success(request);
        } else {
            failure(request);
        }
    }] start];

    UAActionFetchResult expectedResult = successful? UAActionFetchResultNewData : UAActionFetchResultFailed;

    [self performWithArgs:args withExpectedFetchResult:expectedResult];
}

- (void)testPerformInBackgroundSuccess {
    [self performInBackground:YES];
}

- (void)testPerformInBackgroundFailure {
    [self performInBackground:NO];
}

- (void)testPerformWithString {
    [self performInForegroundWithValue:self.urlString];
}

- (void)testPerformWithUrl {
    [self performInForegroundWithValue:[NSURL URLWithString:self.urlString]];
}

- (void)testPerformWithSchemelessURL {
    [self performInForegroundWithValue:@"foo.bar.com/whatever"];
}

@end
