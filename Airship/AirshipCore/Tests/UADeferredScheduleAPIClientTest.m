/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UADeferredScheduleAPIClient+Internal.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UADeferredAPIClientResponse+Internal.h"

#import "AirshipTests-Swift.h"

typedef void (^UAHTTPRequestCompletionHandler)(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error);

@interface UADeferredScheduleAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UADeferredScheduleAPIClient *client;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) id mockResponse;
@end

@implementation UADeferredScheduleAPIClientTest

- (void)setUp {
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.mockResponse = [self mockForClass:[NSHTTPURLResponse class]];
    self.client = [UADeferredScheduleAPIClient clientWithConfig:self.config
                                                        session:self.mockSession
                                         stateOverridesProvider:[self testStateOverridesProvider]];
}

- (UAStateOverrides * (^)(void))testStateOverridesProvider {
    return ^ {
        return [UAStateOverrides stateOverridesWithAppVersion:@"1.2.3"
                                                   sdkVersion:@"2.3.4"
                                               localeLanguage:@"en"
                                                localeCountry:@"US"
                                            notificationOptIn:YES];
    };
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
    NSData *responseData = [UAJSONUtils dataWithObject:responseBody options:0 error:nil];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    NSArray *tagUpdates = @[
        [[UATagGroupUpdate alloc] initWithGroup:@"add-group" tags:@[@"tag-1", @"tag-2"] type:UATagGroupUpdateTypeAdd],
        [[UATagGroupUpdate alloc] initWithGroup:@"set-group" tags:@[@"tag-3", @"tag-4"] type:UATagGroupUpdateTypeSet],
        [[UATagGroupUpdate alloc] initWithGroup:@"remove-group" tags:@[@"tag-5", @"tag-6"] type:UATagGroupUpdateTypeRemove],
    ];
    
    NSDate *attributeDate = NSDate.now;
    NSArray *attributeUpdates = @[
        [[UAAttributeUpdate alloc] initWithAttribute:@"remove-attribute" type:UAAttributeUpdateTypeRemove value:nil date:attributeDate],
        [[UAAttributeUpdate alloc] initWithAttribute:@"set-attribute" type:UAAttributeUpdateTypeSet value:@"hi" date:attributeDate]
    ];
    
    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        XCTAssertEqualObjects(request.method, @"POST");
        XCTAssertEqualObjects(request.url, URL);
        XCTAssertEqualObjects(request.headers[@"Accept"], @"application/vnd.urbanairship+json; version=3;");

        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:NSJSONReadingAllowFragments error:nil];
        XCTAssertEqualObjects(body[@"platform"], @"ios");
        XCTAssertEqualObjects(body[@"channel_id"], channelID);

        id expectedTrigger = @{@"type": trigger.typeName, @"goal" : trigger.goal, @"event": event};
        XCTAssertEqualObjects(body[@"trigger"], expectedTrigger);

        
        id exepctedTagOverrides = @{ @"add": @{ @"add-group": @[@"tag-1", @"tag-2"] },
                                     @"set": @{ @"set-group": @[@"tag-3", @"tag-4"] },
                                     @"remove": @{ @"remove-group": @[@"tag-5", @"tag-6"] } };
        
        
        XCTAssertEqualObjects(body[@"tag_overrides"], exepctedTagOverrides);

        id timestamp = [UAUtils.ISODateFormatterUTCWithDelimiter stringFromDate:attributeDate];

        id exepctedAttributeOverrides = @[ @{ @"action": @"remove", @"key": @"remove-attribute", @"timestamp": timestamp},
                                           @{ @"action": @"set", @"value": @"hi", @"key": @"set-attribute", @"timestamp": timestamp} ];

        XCTAssertEqualObjects(body[@"attribute_overrides"], exepctedAttributeOverrides);

        id expectedStateOverrides = @{@"app_version" : @"1.2.3", @"sdk_version" : @"2.3.4",
                                      @"locale_language" : @"en", @"locale_country": @"US",
                                      @"notification_opt_in" : @(YES)};

        XCTAssertEqualObjects(body[@"state_overrides"], expectedStateOverrides);

        [sessionFinished fulfill];

        return YES;
    }] completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:tagUpdates
         attributeOverrides:attributeUpdates
          completionHandler:^(UADeferredAPIClientResponse * _Nullable response, NSError * _Nullable error) {

        XCTAssertNotNil(response.result);
        XCTAssertTrue(response.result.isAudienceMatch);
        XCTAssertNotNil(response.result.message);
        XCTAssertEqualObjects(response.result.message, [UAInAppMessage messageWithJSON:messageJSON defaultSource:UAInAppMessageSourceRemoteData error:nil]);

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
    NSData *responseData = [UAJSONUtils dataWithObject:responseBody options:0 error:nil];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        XCTAssertEqualObjects(request.method, @"POST");
        XCTAssertEqualObjects(request.url, URL);
        XCTAssertEqualObjects(request.headers[@"Accept"], @"application/vnd.urbanairship+json; version=3;");

        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:NSJSONReadingAllowFragments error:nil];
        XCTAssertEqualObjects(body[@"platform"], @"ios");
        XCTAssertEqualObjects(body[@"channel_id"], channelID);

        id expectedTrigger = @{@"type": trigger.typeName, @"goal" : trigger.goal, @"event": event};
        XCTAssertEqualObjects(body[@"trigger"], expectedTrigger);

        XCTAssertNil(body[@"tag_overrides"]);
        XCTAssertNil(body[@"attribute_overrides"]);

        [sessionFinished fulfill];

        return YES;
    }] completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:@[]
         attributeOverrides:@[]
          completionHandler:^(UADeferredAPIClientResponse * _Nullable response, NSError * _Nullable error) {

        XCTAssertNotNil(response.result);
        XCTAssertTrue(response.result.isAudienceMatch);
        XCTAssertNotNil(response.result.message);
        XCTAssertEqualObjects(response.result.message, [UAInAppMessage messageWithJSON:messageJSON defaultSource:UAInAppMessageSourceRemoteData error:nil]);
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
    NSData *responseData = [UAJSONUtils dataWithObject:responseBody options:0 error:nil];


    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;


        XCTAssertEqualObjects(request.method, @"POST");
        XCTAssertEqualObjects(request.url, URL);
        XCTAssertEqualObjects(request.headers[@"Accept"], @"application/vnd.urbanairship+json; version=3;");

        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:NSJSONReadingAllowFragments error:nil];
        XCTAssertEqualObjects(body[@"platform"], @"ios");
        XCTAssertEqualObjects(body[@"channel_id"], channelID);

        XCTAssertNil(body[@"trigger"]);

        [sessionFinished fulfill];

        return YES;
    }] completionHandler:OCMOCK_ANY];
                                     
    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:nil
               tagOverrides:@[]
         attributeOverrides:@[]
          completionHandler:^(UADeferredAPIClientResponse * _Nullable response, NSError * _Nullable error) {

        XCTAssertNotNil(response.result);
        XCTAssertNil(error);
        XCTAssertTrue(response.result.isAudienceMatch);
        XCTAssertNotNil(response.result.message);
        XCTAssertEqualObjects(response.result.message, [UAInAppMessage messageWithJSON:messageJSON defaultSource:UAInAppMessageSourceRemoteData error:nil]);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolveURLTriggerContextNilEvent {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:nil];

    NSDictionary *messageJSON = @{
        @"display": @{@"body": @{
                              @"text":@"the body"
        },
        },
        @"display_type": @"banner"
    };

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSDictionary *responseBody = @{@"audience_match": @(YES), @"type" : @"in_app_message", @"message": messageJSON};
    NSData *responseData = [UAJSONUtils dataWithObject:responseBody options:0 error:nil];


    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;

        XCTAssertEqualObjects(request.method, @"POST");
        XCTAssertEqualObjects(request.url, URL);
        XCTAssertEqualObjects(request.headers[@"Accept"], @"application/vnd.urbanairship+json; version=3;");

        NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.body options:NSJSONReadingAllowFragments error:nil];
        XCTAssertEqualObjects(body[@"platform"], @"ios");
        XCTAssertEqualObjects(body[@"channel_id"], channelID);

        id expectedTrigger = @{@"type": trigger.typeName, @"goal" : trigger.goal};
        XCTAssertEqualObjects(body[@"trigger"], expectedTrigger);

        XCTAssertNil(body[@"tag_overrides"]);
        XCTAssertNil(body[@"attribute_overrides"]);

        [sessionFinished fulfill];

        return YES;
    }] completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:@[]
         attributeOverrides:@[]
          completionHandler:^(UADeferredAPIClientResponse * _Nullable response, NSError * _Nullable error) {

        XCTAssertNotNil(response.result);
        XCTAssertTrue(response.result.isAudienceMatch);
        XCTAssertNotNil(response.result.message);
        XCTAssertEqualObjects(response.result.message, [UAInAppMessage messageWithJSON:messageJSON defaultSource:UAInAppMessageSourceRemoteData error:nil]);
        
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
    [[[self.mockResponse stub] andReturnValue:@401] statusCode];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
                
        NSError *error = [NSError errorWithDomain:@"error_domain" code:100 userInfo:nil];
        completionHandler(nil, self.mockResponse, error);
        [sessionFinished fulfill];
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:@[]
         attributeOverrides:@[]
          completionHandler:^(UADeferredAPIClientResponse * _Nullable response, NSError * _Nullable error) {

        XCTAssertNil(response.result);
        XCTAssertEqual(response.status, 401);
        XCTAssertNotNil(error);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolveURLDefaultResponse {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];
    NSDictionary *responseBody = @{};
    NSData *responseData = [UAJSONUtils dataWithObject:responseBody options:0 error:nil];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
        [sessionFinished fulfill];
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:@[]
         attributeOverrides:@[]
          completionHandler:^(UADeferredAPIClientResponse * _Nullable response, NSError * _Nullable error) {

        XCTAssertNotNil(response.result);
        XCTAssertFalse(response.result.isAudienceMatch);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolve409StatusCode {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];
    [[[self.mockResponse stub] andReturnValue:@409] statusCode];


    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        
        completionHandler(nil, self.mockResponse, nil);
        [sessionFinished fulfill];
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:@[]
         attributeOverrides:@[]
          completionHandler:^(UADeferredAPIClientResponse * _Nullable response, NSError * _Nullable error) {

        XCTAssertNil(response.result);
        XCTAssertEqual(response.status, 409);
        XCTAssertNil(response.rules);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolve429StatusCode {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];
    [[[self.mockResponse stub] andReturn:@{@"Location":@"location",
                                                @"Retry-After":@5
                                              }] allHeaderFields];
    [[[self.mockResponse stub] andReturnValue:@429] statusCode];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        
        completionHandler(nil, self.mockResponse, nil);
        [sessionFinished fulfill];
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:@[]
         attributeOverrides:@[]
          completionHandler:^(UADeferredAPIClientResponse * _Nullable response, NSError * _Nullable error) {

        XCTAssertNil(response.result);
        XCTAssertEqual(response.status, 429);
        XCTAssertEqual(response.rules.location, @"location");
        XCTAssertEqual(response.rules.retryTime, 5);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testResolve307StatusCode {
    NSURL *URL = [NSURL URLWithString:@"https://cool.story/neat"];
    NSString *channelID = @"channelID";
    NSString *event = @"event";
    UAScheduleTrigger *trigger = [UAScheduleTrigger foregroundTriggerWithCount:1];
    UAScheduleTriggerContext *triggerContext = [UAScheduleTriggerContext triggerContextWithTrigger:trigger event:event];
    [[[self.mockResponse stub] andReturn:@{@"Location":@"location",
                                                @"Retry-After":@5
                                              }] allHeaderFields];
    [[[self.mockResponse stub] andReturnValue:@307] statusCode];

    XCTestExpectation *sessionFinished = [self expectationWithDescription:@"Session finished"];

    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        
        completionHandler(nil, self.mockResponse, nil);
        [sessionFinished fulfill];
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *resultResolved = [self expectationWithDescription:@"Result resolved"];

    [self.client resolveURL:URL
                  channelID:channelID
             triggerContext:triggerContext
               tagOverrides:@[]
         attributeOverrides:@[]
          completionHandler:^(UADeferredAPIClientResponse * _Nullable response, NSError * _Nullable error) {

        XCTAssertNil(response.result);
        XCTAssertEqual(response.status, 307);
        XCTAssertEqual(response.rules.location, @"location");
        XCTAssertEqual(response.rules.retryTime, 5);

        [resultResolved fulfill];
    }];

    [self waitForTestExpectations];
}


@end

