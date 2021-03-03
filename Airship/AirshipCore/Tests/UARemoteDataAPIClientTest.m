/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UARuntimeConfig.h"
#import "UARequestSession.h"
#import "UARemoteDataAPIClient+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UAirshipVersion.h"

@interface UARemoteDataAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UARemoteDataAPIClient *remoteDataAPIClient;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, copy) NSArray *remoteData;

@end

@implementation UARemoteDataAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.remoteDataAPIClient = [UARemoteDataAPIClient clientWithConfig:self.config
                                                               session:self.mockSession];
    self.config.appKey = @"appKey";

    self.remoteData = @[ @{ @"type": @"test_data_type",
                            @"timestamp":@"2017-01-01T12:00:00",
                            @"data": @{ @"message_center" :
                                            @{ @"background_color" : @"0000FF",
                                               @"font" : @"Comic Sans"
                                            }

                            }
    }];
}

- (void)testFetchRemoteData {
    // Create a successful response
    NSData *responseData = [self createRemoteDataResponseForPayloads:self.remoteData];
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":responseLastModified}];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;
        NSString *expected = [NSString stringWithFormat:@"https://remote-data.urbanairship.com/api/remote-data/app/%@/ios?sdk_version=%@&language=%@&country=%@", self.config.appKey, [UAirshipVersion get], [NSLocale currentLocale].languageCode, [NSLocale currentLocale].countryCode];

        return [[request.URL absoluteString] isEqualToString:expected];
    }] completionHandler:OCMOCK_ANY];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:[NSLocale currentLocale]
                                           lastModified:nil
                                      completionHandler:^(NSArray<NSDictionary *> * _Nullable remoteData, NSString * _Nullable lastModified, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(self.remoteData, remoteData);
        XCTAssertEqualObjects(responseLastModified, lastModified);
        [refreshFinished fulfill];
    }];

    // Wait for the test expectations
    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testFetchRemoteData304 {
    NSString *lastModified = @"2017-01-01T12:00:00";
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:304
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":lastModified}];
    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(nil, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;
        NSString *expected = [NSString stringWithFormat:@"https://remote-data.urbanairship.com/api/remote-data/app/%@/ios?sdk_version=%@&language=%@&country=%@", self.config.appKey, [UAirshipVersion get], [NSLocale currentLocale].languageCode, [NSLocale currentLocale].countryCode];

        return [[request.URL absoluteString] isEqualToString:expected] && [request.headers[@"If-Modified-Since"] isEqual:lastModified];
    }] completionHandler:OCMOCK_ANY];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:[NSLocale currentLocale]
                                           lastModified:lastModified
                                      completionHandler:^(NSArray<NSDictionary *> * _Nullable remoteData, NSString * _Nullable responseLastModified, NSError * _Nullable error) {
        XCTAssertNil(remoteData);
        XCTAssertNil(error);
        XCTAssertNil(responseLastModified);
        [refreshFinished fulfill];
    }];

    // Wait for the test expectations
    [self waitForTestExpectations];
    [self.mockSession verify];
}


/**
 * Test refresh the remote data when no remote data returned from cloud
 */
- (void)testFetchRemoteDataNoPayloads {
    NSData *responseData = [self createRemoteDataResponseForPayloads:@[]];
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":responseLastModified}];

    // Stub the session to return the esponse
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;
        NSString *expected = [NSString stringWithFormat:@"https://remote-data.urbanairship.com/api/remote-data/app/%@/ios?sdk_version=%@&language=%@&country=%@", self.config.appKey, [UAirshipVersion get], [NSLocale currentLocale].languageCode, [NSLocale currentLocale].countryCode];

        return [[request.URL absoluteString] isEqualToString:expected];
    }] completionHandler:OCMOCK_ANY];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:[NSLocale currentLocale]
                                           lastModified:nil
                                      completionHandler:^(NSArray<NSDictionary *> * _Nullable remoteData, NSString * _Nullable lastModified, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(@[], remoteData);
        XCTAssertEqualObjects(responseLastModified, lastModified);
        [refreshFinished fulfill];
    }];


    // Wait for the test expectations
    [self waitForTestExpectations];
    [self.mockSession verify];
}


- (void)testVersion {
    NSString *expectedVersionQuery = [NSString stringWithFormat:@"sdk_version=%@", [UAirshipVersion get]];

    NSData *responseData = [self createRemoteDataResponseForPayloads:self.remoteData];
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":responseLastModified}];


    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData,response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;
        NSArray *queryComponents = [request.URL.query componentsSeparatedByString:@"&"];
        return [queryComponents containsObject:expectedVersionQuery];
    }] completionHandler:OCMOCK_ANY];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:[NSLocale currentLocale]
                                           lastModified:nil
                                      completionHandler:^(NSArray<NSDictionary *> * _Nullable remoteData, NSString * _Nullable lastModified, NSError * _Nullable error) {
        [refreshFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testLocale {
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en-01"];

    NSString *expectedLanguageQuery = @"language=en";
    NSString *expectedCountryQuery = @"country=01";

    NSData *responseData = [self createRemoteDataResponseForPayloads:self.remoteData];
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":responseLastModified}];


    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData,response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;
        NSArray *queryComponents = [request.URL.query componentsSeparatedByString:@"&"];
        return [queryComponents containsObject:expectedLanguageQuery] && [queryComponents containsObject:expectedCountryQuery];
    }] completionHandler:OCMOCK_ANY];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:locale
                                           lastModified:nil
                                      completionHandler:^(NSArray<NSDictionary *> * _Nullable remoteData, NSString * _Nullable lastModified, NSError * _Nullable error) {
        [refreshFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (void)testLocaleMissingCountry {
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];

    NSData *responseData = [self createRemoteDataResponseForPayloads:self.remoteData];
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":responseLastModified}];


    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData,response, nil);
    }] performHTTPRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
        UARequest *request = obj;
        return ![request.URL.query containsString:@"country="];
    }] completionHandler:OCMOCK_ANY];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:locale
                                           lastModified:nil
                                      completionHandler:^(NSArray<NSDictionary *> * _Nullable remoteData, NSString * _Nullable lastModified, NSError * _Nullable error) {
        [refreshFinished fulfill];
    }];

    [self waitForTestExpectations];
}

- (NSData *)createRemoteDataResponseForPayloads:(NSArray *)payloads {
    NSDictionary *responseDict = @{ @"ok" : @YES,
                                    @"payloads" : payloads
    };

    NSError *error;
    NSData *remoteData = [NSJSONSerialization dataWithJSONObject:responseDict options:NSJSONWritingPrettyPrinted error:&error];

    XCTAssertNil(error ,@"Error creating remote data of from array %@: %@", payloads, error.localizedDescription);

    return remoteData;
}

@end

