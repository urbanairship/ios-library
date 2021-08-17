/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "UAUser+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAUserData+Internal.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

typedef void (^UAHTTPRequestCompletionHandler)(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error);

@interface UAInboxAPIClientTest : UAAirshipBaseTest

@property (nonatomic, strong) UAInboxAPIClient *inboxAPIClient;
@property (nonatomic, strong) id mockUser;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) UATestRequestSession *testSession;
@end

@implementation UAInboxAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockChannel = [self mockForClass:[UAChannel class]];
       [[[self.mockChannel stub] andReturn:@"mockChannelID"] identifier];


    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];


    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel stub] andReturn:@"mockChannelID"] identifier];

    self.mockUser = [self mockForClass:[UAUser class]];
    UAUserData *userData = [UAUserData dataWithUsername:@"username" password:@"password"];

    [[[self.mockUser stub] andReturn:userData] getUserDataSync];

    self.testSession = [[UATestRequestSession alloc] init];

    
    self.inboxAPIClient = [UAInboxAPIClient clientWithConfig:self.config
                                                     session:self.testSession
                                                        user:self.mockUser
                                                   dataStore:self.dataStore];
}

/**
 * Tests retrieving the message list with success.
 */
- (void)testRetrieveMessageListSuccess {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    self.testSession.data = [@"{\"ok\":true, \"messages\": [\"someMessage\"]}" dataUsingEncoding:NSUTF8StringEncoding];

    NSError *error;
    NSArray *messages = [self.inboxAPIClient retrieveMessageList:&error];

    XCTAssertEqualObjects(messages[0], @"someMessage", @"Messages should match messages from the response");
    XCTAssertNil(error);

    UARequest *request = self.testSession.lastRequest;

    XCTAssertEqualObjects(@"https://device-api.urbanairship.com/api/user/username/messages/", request.url.absoluteString);
    XCTAssertEqualObjects(@"GET", request.method);
    XCTAssertEqualObjects(@"mockChannelID", request.headers[kUAChannelIDHeader]);
}

/**
 * Tests retrieving the message list with failure
 */
- (void)testRetrieveMessageListFailure {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];
    NSError *error;
    NSArray *messages = [self.inboxAPIClient retrieveMessageList:&error];

    XCTAssertNil(messages, @"Messages should be nil");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, UAInboxAPIClientErrorUnsuccessfulStatus);
}

/**
 * Tests retrieving the message list with an invalid response
*/
- (void)testRetrieveMessageListInvalidResponse {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSError *error;
    NSArray *messages = [self.inboxAPIClient retrieveMessageList:&error];

    XCTAssertNil(messages, @"Messages should be nil");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, UAInboxAPIClientErrorInvalidResponse);
}

/**
 * Tests batch mark as read success.
 */
- (void)testBatchMarkAsReadSuccess {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    self.testSession.data = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    BOOL success = [self.inboxAPIClient performBatchMarkAsReadForMessageReporting:@[testReporting]];
    XCTAssertTrue(success);
}

/**
 * Tests batch mark as read failure.
 */
- (void)testBatchMarkAsReadFailure {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    BOOL success = [self.inboxAPIClient performBatchMarkAsReadForMessageReporting:@[testReporting]];
    XCTAssertFalse(success);
}

/**
 * Tests batch delete success.
 */
- (void)testBatchDeleteSuccess {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    self.testSession.data = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    BOOL success = [self.inboxAPIClient performBatchDeleteForMessageReporting:@[testReporting]];
    XCTAssertTrue(success);
}

/**
 * Tests batch delete failure.
 */
- (void)testBatchDeleteFailure {
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    BOOL success = [self.inboxAPIClient performBatchDeleteForMessageReporting:@[testReporting]];
    XCTAssertFalse(success);
}

@end
