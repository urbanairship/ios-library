/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UADeferredScheduleAPIClient+Internal.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAInAppMessage+Internal.h"

@interface UADeferredScheduleAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UADeferredScheduleAPIClient *client;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) id mockAuthManager;
@end

@implementation UADeferredScheduleAPIClientTest

- (void)setUp {
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.mockAuthManager = [self mockForClass:[UAAuthTokenManager class]];
    self.client = [UADeferredScheduleAPIClient clientWithConfig:self.config session:self.mockSession authManager:self.mockAuthManager];
}

- (void)testResolveURL {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];

    NSDictionary *messageJSON = @{
                                @"display": @{@"body": @{
                                                        @"text":@"the body"
                                                        },
                                            },
                                @"display_type": @"banner"
                                };

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSDictionary *responseBody = @{@"audience_match": @(YES), @"type" : @"in_app_message", @"message": messageJSON};
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseBody options:0 error:nil];

    NSString *token = @"token";

    XCTestExpectation *authTokenRetrieved = [self expectationWithDescription:@"Auth token retrieved"];

    [[[self.mockAuthManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];

        void (^handler)(NSString * _NullablemeterTypes) = (__bridge void (^_Nonnull)(NSString * _Nullable))arg;
        handler(token);
        [authTokenRetrieved fulfill];
    }] tokenWithCompletionHandler:OCMOCK_ANY];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"neat", @"rad"] group:@"cool"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToAddTags:@[@"awesome", @"nice"] group:@"great"];

    NSArray<UATagGroupsMutation *> *tagOverrides = @[mutation, mutation2];

    UAAttributeMutations *attributeMutations = [UAAttributeMutations mutations];
    [attributeMutations setString:@"absolutely" forAttribute:@"fabulous"];
    UAAttributePendingMutations *attributeOverrides = [UAAttributePendingMutations pendingMutationsWithMutations:attributeMutations
                                                                                                             date:[[UADate alloc] init]];
    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        XCTAssertEqualObjects(request.method, @"POST");
        XCTAssertEqualObjects(request.URL, URL);
        XCTAssertEqualObjects(request.headers[@"Accept"], @"application/vnd.urbanairship+json; version=3;");
        XCTAssertEqualObjects(request.headers[@"Authorization"], [@"Bearer " stringByAppendingString:token]);

        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:NSJSONReadingAllowFragments error:nil];
        XCTAssertEqualObjects(body[@"platform"], @"ios");
        XCTAssertEqualObjects(body[@"channel_id"], channelID);

        id expectedTrigger = @{@"type": trigger.typeName, @"goal" : trigger.goal, @"event": event};
        XCTAssertEqualObjects(body[@"trigger"], expectedTrigger);

        id expectedOverrides = @[mutation.payload, mutation2.payload];
        XCTAssertEqualObjects(body[@"tag_overrides"], expectedOverrides);

        XCTAssertEqualObjects(body[@"attribute_overrides"], attributeOverrides.mutationsPayload);

        [sessionFinished fulfill];

        return YES;
    }] retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:tagOverrides
         attributeOverrides:attributeOverrides
          completionHandler:^(UADeferredScheduleResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(result);
        XCTAssertTrue(result.isAudienceMatch);
        XCTAssertNotNil(result.message);
        XCTAssertEqualObjects(result.message, [UAInAppMessage messageWithJSON:messageJSON error:nil]);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolveURLEmptyOverrides {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];

    NSDictionary *messageJSON = @{
                                @"display": @{@"body": @{
                                                        @"text":@"the body"
                                                        },
                                            },
                                @"display_type": @"banner"
                                };

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSDictionary *responseBody = @{@"audience_match": @(YES), @"type" : @"in_app_message", @"message": messageJSON};
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseBody options:0 error:nil];

    NSString *token = @"token";

    XCTestExpectation *authTokenRetrieved = [self expectationWithDescription:@"Auth token retrieved"];

    [[[self.mockAuthManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];

        void (^handler)(NSString * _NullablemeterTypes) = (__bridge void (^_Nonnull)(NSString * _Nullable))arg;
        handler(token);
        [authTokenRetrieved fulfill];
    }] tokenWithCompletionHandler:OCMOCK_ANY];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    NSArray<UATagGroupsMutation *> *tagOverrides = @[];

    UAAttributeMutations *attributeMutations = [UAAttributeMutations mutations];
    UAAttributePendingMutations *attributeOverrides = [UAAttributePendingMutations pendingMutationsWithMutations:attributeMutations
                                                                                                             date:[[UADate alloc] init]];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        XCTAssertEqualObjects(request.method, @"POST");
        XCTAssertEqualObjects(request.URL, URL);
        XCTAssertEqualObjects(request.headers[@"Accept"], @"application/vnd.urbanairship+json; version=3;");
        XCTAssertEqualObjects(request.headers[@"Authorization"], [@"Bearer " stringByAppendingString:token]);

        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:NSJSONReadingAllowFragments error:nil];
        XCTAssertEqualObjects(body[@"platform"], @"ios");
        XCTAssertEqualObjects(body[@"channel_id"], channelID);

        id expectedTrigger = @{@"type": trigger.typeName, @"goal" : trigger.goal, @"event": event};
        XCTAssertEqualObjects(body[@"trigger"], expectedTrigger);

        XCTAssertNil(body[@"tag_overrides"]);
        XCTAssertNil(body[@"attribute_overrides"]);

        [sessionFinished fulfill];

        return YES;
    }] retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:tagOverrides
         attributeOverrides:attributeOverrides
          completionHandler:^(UADeferredScheduleResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(result);
        XCTAssertTrue(result.isAudienceMatch);
        XCTAssertNotNil(result.message);
        XCTAssertEqualObjects(result.message, [UAInAppMessage messageWithJSON:messageJSON error:nil]);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolveURLTriggerContextNil {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";

    NSDictionary *messageJSON = @{
                                @"display": @{@"body": @{
                                                        @"text":@"the body"
                                                        },
                                            },
                                @"display_type": @"banner"
                                };

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSDictionary *responseBody = @{@"audience_match": @(YES), @"type" : @"in_app_message", @"message": messageJSON};
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseBody options:0 error:nil];

    NSString *token = @"token";

    XCTestExpectation *authTokenRetrieved = [self expectationWithDescription:@"Auth token retrieved"];

    [[[self.mockAuthManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];

        void (^handler)(NSString * _NullablemeterTypes) = (__bridge void (^_Nonnull)(NSString * _Nullable))arg;
        handler(token);
        [authTokenRetrieved fulfill];
    }] tokenWithCompletionHandler:OCMOCK_ANY];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;


        XCTAssertEqualObjects(request.method, @"POST");
        XCTAssertEqualObjects(request.URL, URL);
        XCTAssertEqualObjects(request.headers[@"Accept"], @"application/vnd.urbanairship+json; version=3;");
        XCTAssertEqualObjects(request.headers[@"Authorization"], [@"Bearer " stringByAppendingString:token]);

        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:NSJSONReadingAllowFragments error:nil];
        XCTAssertEqualObjects(body[@"platform"], @"ios");
        XCTAssertEqualObjects(body[@"channel_id"], channelID);

        XCTAssertNil(body[@"trigger"]);

        [sessionFinished fulfill];

        return YES;
    }] retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"neat", @"rad"] group:@"cool"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToAddTags:@[@"awesome", @"nice"] group:@"great"];

    NSArray<UATagGroupsMutation *> *tagOverrides = @[mutation, mutation2];

    UAAttributeMutations *attributeMutations = [UAAttributeMutations mutations];
    [attributeMutations setString:@"absolutely" forAttribute:@"fabulous"];
    UAAttributePendingMutations *attributeOverrides = [UAAttributePendingMutations pendingMutationsWithMutations:attributeMutations
                                                                                                             date:[[UADate alloc] init]];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:nil
               tagOverrides:tagOverrides
         attributeOverrides:attributeOverrides
          completionHandler:^(UADeferredScheduleResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertTrue(result.isAudienceMatch);
        XCTAssertNotNil(result.message);
        XCTAssertEqualObjects(result.message, [UAInAppMessage messageWithJSON:messageJSON error:nil]);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolveURLMissingAuthToken {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];

    XCTestExpectation *authTokenRetrieved = [self expectationWithDescription:@"Auth token retrieved"];

    [[[self.mockAuthManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];

        void (^handler)(NSString * _NullablemeterTypes) = (__bridge void (^_Nonnull)(NSString * _Nullable))arg;
        handler(nil);
        [authTokenRetrieved fulfill];
    }] tokenWithCompletionHandler:OCMOCK_ANY];

    [[self.mockSession reject] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"neat", @"rad"] group:@"cool"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToAddTags:@[@"awesome", @"nice"] group:@"great"];

    NSArray<UATagGroupsMutation *> *tagOverrides = @[mutation, mutation2];

    UAAttributeMutations *attributeMutations = [UAAttributeMutations mutations];
    [attributeMutations setString:@"absolutely" forAttribute:@"fabulous"];
    UAAttributePendingMutations *attributeOverrides = [UAAttributePendingMutations pendingMutationsWithMutations:attributeMutations
                                                                                                             date:[[UADate alloc] init]];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:tagOverrides
         attributeOverrides:attributeOverrides
          completionHandler:^(UADeferredScheduleResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, UADeferredScheduleAPIClientErrorDomain);
        XCTAssertEqual(error.code, UADeferredScheduleAPIClientErrorMissingAuthToken);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolveURLTimeout {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];

    NSString *token = @"token";

    XCTestExpectation *authTokenRetrieved = [self expectationWithDescription:@"Auth token retrieved"];

    [[[self.mockAuthManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];

        void (^handler)(NSString * _NullablemeterTypes) = (__bridge void (^_Nonnull)(NSString * _Nullable))arg;
        handler(token);
        [authTokenRetrieved fulfill];
    }] tokenWithCompletionHandler:OCMOCK_ANY];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        NSError *error = [NSError errorWithDomain:@"domain" code:0 userInfo:@{}];
        completionHandler(nil, nil, error);
        [sessionFinished fulfill];
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"neat", @"rad"] group:@"cool"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToAddTags:@[@"awesome", @"nice"] group:@"great"];

    NSArray<UATagGroupsMutation *> *tagOverrides = @[mutation, mutation2];

    UAAttributeMutations *attributeMutations = [UAAttributeMutations mutations];
    [attributeMutations setString:@"absolutely" forAttribute:@"fabulous"];
    UAAttributePendingMutations *attributeOverrides = [UAAttributePendingMutations pendingMutationsWithMutations:attributeMutations
                                                                                                             date:[[UADate alloc] init]];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:tagOverrides
         attributeOverrides:attributeOverrides
          completionHandler:^(UADeferredScheduleResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, UADeferredScheduleAPIClientErrorDomain);
        XCTAssertEqual(error.code, UADeferredScheduleAPIClientErrorTimedOut);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolveURLAuthTokenStale {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];


    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:401 HTTPVersion:nil headerFields:nil];
    NSDictionary *responseBody = @{@"audience_match": @(YES), @"type" : @"whatever"};
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseBody options:0 error:nil];

    NSString *token = @"token";
    NSString *newToken = @"newToken";

    XCTestExpectation *authTokenRetrieved = [self expectationWithDescription:@"Auth token retrieved"];

    [[[self.mockAuthManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];

        void (^handler)(NSString * _NullablemeterTypes) = (__bridge void (^_Nonnull)(NSString * _Nullable))arg;
        handler(token);
        [authTokenRetrieved fulfill];
    }] tokenWithCompletionHandler:OCMOCK_ANY];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
        [sessionFinished fulfill];
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"neat", @"rad"] group:@"cool"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToAddTags:@[@"awesome", @"nice"] group:@"great"];

    NSArray<UATagGroupsMutation *> *tagOverrides = @[mutation, mutation2];

    UAAttributeMutations *attributeMutations = [UAAttributeMutations mutations];
    [attributeMutations setString:@"absolutely" forAttribute:@"fabulous"];
    UAAttributePendingMutations *attributeOverrides = [UAAttributePendingMutations pendingMutationsWithMutations:attributeMutations
                                                                                                             date:[[UADate alloc] init]];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:tagOverrides
         attributeOverrides:attributeOverrides
          completionHandler:^(UADeferredScheduleResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(result);
        XCTAssertTrue(result.isAudienceMatch);

        [resultResolved fulfill];
    }];

    XCTestExpectation *newTokenRetrieved = [self expectationWithDescription:@"New auth token retrieved"];

    [[self.mockAuthManager expect] expireToken:token];

    [[[self.mockAuthManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];

        void (^handler)(NSString * _NullablemeterTypes) = (__bridge void (^_Nonnull)(NSString * _Nullable))arg;
        handler(newToken);
        [newTokenRetrieved fulfill];
    }] tokenWithCompletionHandler:OCMOCK_ANY];

    XCTestExpectation *newSessionFinished = [self expectationWithDescription:@"New session finished"];

    response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
        [newSessionFinished fulfill];
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self waitForTestExpectations];
    [self.mockAuthManager verify];
}

- (void)testResolveURLDefaultResponse {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSDictionary *responseBody = @{};
    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseBody options:0 error:nil];

    NSString *token = @"token";

    XCTestExpectation *authTokenRetrieved = [self expectationWithDescription:@"Auth token retrieved"];

    [[[self.mockAuthManager expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];

        void (^handler)(NSString * _NullablemeterTypes) = (__bridge void (^_Nonnull)(NSString * _Nullable))arg;
        handler(token);
        [authTokenRetrieved fulfill];
    }] tokenWithCompletionHandler:OCMOCK_ANY];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
        [sessionFinished fulfill];
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:@[@"neat", @"rad"] group:@"cool"];
    UATagGroupsMutation *mutation2 = [UATagGroupsMutation mutationToAddTags:@[@"awesome", @"nice"] group:@"great"];

    NSArray<UATagGroupsMutation *> *tagOverrides = @[mutation, mutation2];

    UAAttributeMutations *attributeMutations = [UAAttributeMutations mutations];
    [attributeMutations setString:@"absolutely" forAttribute:@"fabulous"];
    UAAttributePendingMutations *attributeOverrides = [UAAttributePendingMutations pendingMutationsWithMutations:attributeMutations
                                                                                                             date:[[UADate alloc] init]];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:tagOverrides
         attributeOverrides:attributeOverrides
          completionHandler:^(UADeferredScheduleResult * _Nullable result, NSError * _Nullable error) {

        XCTAssertNotNil(result);
        XCTAssertFalse(result.isAudienceMatch);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

@end
