/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "UAWebViewCallData.h"
#import "UAirship.h"

@interface UANativeBridgeTest : UABaseTest
@property (nonatomic, strong) JSContext *jsc;
@property (nonatomic, copy) NSString *nativeBridge;
@property (nonatomic, strong) id mockWebView;

@end

@implementation UANativeBridgeTest

- (void)setUp {
    [super setUp];

    self.mockWebView = [self mockForClass:[WKWebView class]];

    NSString *path = [[UAirship resources] pathForResource:@"UANativeBridge" ofType:@""];
    self.nativeBridge = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];


    self.jsc = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];

    //UAirship and window are only used for storage – the former is injected when setting up a WKWebView,
    //and the latter appears to be non-existant in JavaScriptCore
    [self.jsc evaluateScript:@"_UAirship = {}"];
    [self.jsc evaluateScript:@"window = {}"];

    [self.jsc evaluateScript:self.nativeBridge];
}

- (void)tearDown {
    [self.mockWebView stopMocking];
    [super tearDown];
}


- (void)testRunAction {

    __block NSString *finishResult;
    __block NSString *actionURL;

    // Document body
    self.jsc[@"document"] = @{
                              @"createElement":^(NSString *element){
                                  return @{@"style":@{}};
                              },
                              @"body": @{
                                      @"appendChild":^(id child){
                                          // Capture the action URL
                                          actionURL = child[@"src"];
                                      },
                                      @"removeChild":^(id child){
                                          // no-op
                                      }}};

    // Function invoked by the runAction callback, for verification
    self.jsc[@"finishTest"] = ^(NSString *result){
        finishResult = result;
    };

    // Run the action
    [self.jsc evaluateScript:@"UAirship.runAction('test_action', 'foo', function(err, result) { finishTest(result) })"];

    // Verify the action URL
    XCTAssertEqualObjects(@"uairship://run-action-cb/test_action/%22foo%22/ua-cb-1", actionURL);

    // Finish the action
    [self.jsc evaluateScript:@"UAirship.finishAction(null, 'done', 'ua-cb-1')"];


    // Verify the result
    XCTAssertEqualObjects(@"done", finishResult);
}

@end
