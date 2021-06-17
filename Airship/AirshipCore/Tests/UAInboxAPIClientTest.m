/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARuntimeConfig.h"
#import "UAirship+Internal.h"
#import "UAChannel.h"
#import "UAUser+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAUserData+Internal.h"
#import "UARequestSession.h"

@import AirshipCore;

@interface UAInboxAPIClientTest : UAAirshipBaseTest

@property (nonatomic, strong) UAInboxAPIClient *inboxAPIClient;
@property (nonatomic, strong) id mockUser;
@property (nonatomic, strong) id mockAirship;
@property (nonatomic, strong) id mockChannel;
@property (nonatomic, strong) id mockSession;
@end

@implementation UAInboxAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel stub] andReturn:@"mockChannelID"] identifier];

    self.mockSession = [self mockForClass:[UARequestSession class]];

    self.mockAirship = [self mockForClass:[UAirship class]];
    [UAirship setSharedAirship:self.mockAirship];
    [[[self.mockAirship stub] andReturn:self.mockChannel] channel];

    self.mockUser = [self mockForClass:[UAUser class]];

    UAUserData *userData = [UAUserData dataWithUsername:@"username" password:@"password"];

    [[[self.mockUser stub] andReturn:userData] getUserDataSync];

    self.inboxAPIClient = [UAInboxAPIClient clientWithConfig:self.config
                                                     session:self.mockSession
                                                        user:self.mockUser
                                                   dataStore:self.dataStore];
}

/**
 * Tests retrieving the message list with success.
 */
- (void)testRetrieveMessageListSuccess {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{\"ok\":true, \"messages\": [\"someMessage\"]}" dataUsingEncoding:NSUTF8StringEncoding];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
        [invocation setReturnValue:(__bridge void *)([UADisposable disposableWithBlock:^{}])];
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    NSError *error;
    NSArray *messages = [self.inboxAPIClient retrieveMessageList:&error];

    XCTAssertEqualObjects(messages[0], @"someMessage", @"Messages should match messages from the response");
    XCTAssertNil(error);

    [self.mockSession verify];
}

/**
 * Tests retrieving the message list with failure
 */
- (void)testRetrieveMessageListFailure {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, [NSError errorWithDomain:UAInboxAPIClientErrorDomain
                                                             code:UAInboxAPIClientErrorUnsuccessfulStatus
                                                         userInfo:nil]);
        [invocation setReturnValue:(__bridge void *)([UADisposable disposableWithBlock:^{}])];
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    NSError *error;
    NSArray *messages = [self.inboxAPIClient retrieveMessageList:&error];

    XCTAssertNil(messages, @"Messages should be nil");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, UAInboxAPIClientErrorUnsuccessfulStatus);

    [self.mockSession verify];
}

/**
 * Tests retrieving the message list with an invalid response
*/
- (void)testRetrieveMessageListInvalidResponse {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, [NSError errorWithDomain:UAInboxAPIClientErrorDomain code:UAInboxAPIClientErrorInvalidResponse userInfo:nil]);
        [invocation setReturnValue:(__bridge void *)([UADisposable disposableWithBlock:^{}])];
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    NSError *error;
    NSArray *messages = [self.inboxAPIClient retrieveMessageList:&error];

    XCTAssertNil(messages, @"Messages should be nil");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, UAInboxAPIClientErrorInvalidResponse);

    [self.mockSession verify];
}

/**
 * Tests batch mark as read success.
 */
- (void)testBatchMarkAsReadSuccess {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
        [invocation setReturnValue:(__bridge void *)([UADisposable disposableWithBlock:^{}])];
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    BOOL success = [self.inboxAPIClient performBatchMarkAsReadForMessageReporting:@[testReporting]];
    XCTAssertTrue(success);

    [self.mockSession verify];
}

/**
 * Tests batch mark as read failure.
 */
- (void)testBatchMarkAsReadFailure {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, [NSError errorWithDomain:UAInboxAPIClientErrorDomain code:UAInboxAPIClientErrorUnsuccessfulStatus userInfo:nil]);
        [invocation setReturnValue:(__bridge void *)([UADisposable disposableWithBlock:^{}])];
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    BOOL success = [self.inboxAPIClient performBatchMarkAsReadForMessageReporting:@[testReporting]];
    XCTAssertFalse(success);

    [self.mockSession verify];
}

/**
 * Tests batch delete success.
 */
- (void)testBatchDeleteSuccess {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:@{}];
    NSData *responseData = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
        [invocation setReturnValue:(__bridge void *)([UADisposable disposableWithBlock:^{}])];
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    BOOL success = [self.inboxAPIClient performBatchDeleteForMessageReporting:@[testReporting]];
    XCTAssertTrue(success);

    [self.mockSession verify];
}

/**
 * Tests batch delete failure.
 */
- (void)testBatchDeleteFailure {
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:500 HTTPVersion:nil headerFields:@{}];

    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, [NSError errorWithDomain:UAInboxAPIClientErrorDomain code:UAInboxAPIClientErrorUnsuccessfulStatus userInfo:nil]);
        [invocation setReturnValue:(__bridge void *)([UADisposable disposableWithBlock:^{}])];
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        if (![@"mockChannelID" isEqualToString:request.headers[kUAChannelIDHeader]]) {
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    NSDictionary *testReporting = @{@"message_id":@"126",
                                    @"group_id":@"345",
                                    @"variant_id":@"1"};

    BOOL success = [self.inboxAPIClient performBatchDeleteForMessageReporting:@[testReporting]];
    XCTAssertFalse(success);

    [self.mockSession verify];
}

@end
