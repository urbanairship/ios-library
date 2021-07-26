/* Copyright Airship and Contributors */

#import <JavaScriptCore/JavaScriptCore.h>
#import "UAAirshipBaseTest.h"
#import "UAJavaScriptEnvironment.h"
#import "UAirship+Internal.h"
#import "UAChannel.h"
#import "UARuntimeConfig.h"

@import AirshipCore;

@interface UAJavaScriptEnvironmentTest : UAAirshipBaseTest
@property (nonatomic, strong) JSContext *jsc;
@property (nonatomic, strong) id mockUIDevice;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockContact;
@end

@implementation UAJavaScriptEnvironmentTest

- (void)setUp {
    [super setUp];
    self.jsc = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
    [self.jsc evaluateScript:@"window = {}"];

    self.mockChannel = [self mockForClass:[UAChannel class]];
    self.mockContact = [self mockForClass:[UAContact class]];
    self.mockUIDevice = [self mockForClass:[UIDevice class]];
    [[[self.mockUIDevice stub] andReturn:self.mockUIDevice] currentDevice];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];
    [[[self.mockAirship stub] andReturn:self.mockContact] contact];
    [[[self.mockAirship stub] andReturn:self.config] config];

    [UAirship setSharedAirship:self.mockAirship];
}

/**
 * Test default envionment getters.
 */
- (void)testDefaultEnvironment {
    [[[self.mockUIDevice stub] andReturn:@"device model"] model];
    [[[self.mockChannel stub] andReturn:@"channel ID"] identifier];
    [[[self.mockContact stub] andReturn:@"named user"] namedUserID];

    // Inject the default JavaScript environment
    [self.jsc evaluateScript:[[UAJavaScriptEnvironment defaultEnvironment] build]];

    // Verify the default getters
    XCTAssertEqualObjects(@"device model", [self.jsc evaluateScript:@"UAirship.getDeviceModel()"].toString);
    XCTAssertEqualObjects(@"channel ID", [self.jsc evaluateScript:@"UAirship.getChannelId()"].toString);
    XCTAssertEqualObjects(@"named user", [self.jsc evaluateScript:@"UAirship.getNamedUser()"].toString);
    XCTAssertEqualObjects(self.config.appKey, [self.jsc evaluateScript:@"UAirship.getAppKey()"].toString);

    // Verify native bridge methods are not undefined
    XCTAssertFalse([self.jsc evaluateScript:@"UAirship.runAction"].isUndefined);
    XCTAssertFalse([self.jsc evaluateScript:@"UAirship.finishAction"].isUndefined);
}

/**
 * Test adding custom  number getters.
 */
- (void)testAddingNumberGetters {
    UAJavaScriptEnvironment *environment = [[UAJavaScriptEnvironment alloc] init];
    [environment addNumberGetter:@"nilNumber" value:nil];
    [environment addNumberGetter:@"double" value:@(200.00)];
    [environment addNumberGetter:@"float" value:@(100.3f)];
    [environment addNumberGetter:@"true" value:@(YES)];
    [environment addNumberGetter:@"false" value:@(NO)];
    [environment addNumberGetter:@"int" value:@(1)];

    // Inject the JavaScript environment
    [self.jsc evaluateScript:[environment build]];

    XCTAssertEqualObjects(@(-1), [self.jsc evaluateScript:@"UAirship.nilNumber()"].toNumber);
    XCTAssertEqualWithAccuracy(200.0, [self.jsc evaluateScript:@"UAirship.double()"].toDouble, .1);
    XCTAssertEqualWithAccuracy(100.3, [self.jsc evaluateScript:@"UAirship.float()"].toDouble, .1);
    XCTAssertEqualObjects(@(YES), [self.jsc evaluateScript:@"UAirship.true()"].toNumber);
    XCTAssertEqualObjects(@(NO), [self.jsc evaluateScript:@"UAirship.false()"].toNumber);
    XCTAssertEqualObjects(@(1), [self.jsc evaluateScript:@"UAirship.int()"].toNumber);
}

/**
 * Test adding custom string  getters.
 */
- (void)testAddingStringGetters {
    UAJavaScriptEnvironment *environment = [[UAJavaScriptEnvironment alloc] init];
    [environment addStringGetter:@"nilString" value:nil];
    [environment addStringGetter:@"invalidJSON" value:@"\"\t\b\r\n\f/title"];
    [environment addStringGetter:@"string" value:@"oh hi!"];

    // Inject the JavaScript environment
    [self.jsc evaluateScript:[environment build]];

    XCTAssertEqualObjects(@"null", [self.jsc evaluateScript:@"UAirship.nilString()"].toString);
    XCTAssertEqualObjects(@"\"\t\b\r\n\f/title", [self.jsc evaluateScript:@"UAirship.invalidJSON()"].toString);
    XCTAssertEqualObjects(@"oh hi!", [self.jsc evaluateScript:@"UAirship.string()"].toString);
}

/**
 * Test adding custom dictionary getters.
 */
- (void)testAddingDictionaryGetters {
    UAJavaScriptEnvironment *environment = [[UAJavaScriptEnvironment alloc] init];
    [environment addDictionaryGetter:@"nilDictionary" value:nil];
    [environment addDictionaryGetter:@"dictionary" value:@{@"hey":@"there"}];

    // Inject the JavaScript environment
    [self.jsc evaluateScript:[environment build]];

    XCTAssertEqualObjects(@"null", [self.jsc evaluateScript:@"UAirship.nilDictionary()"].toString);
    XCTAssertEqualObjects(@{@"hey":@"there"}, [self.jsc evaluateScript:@"UAirship.dictionary()"].toDictionary);
}

/**
 * Tes running an action.
 */
- (void)testRunAction {
    // Inject the JavaScript environment
    [self.jsc evaluateScript:[[[UAJavaScriptEnvironment alloc] init] build]];

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
