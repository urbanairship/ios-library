/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UARemoteDataAPIClientTest : UAAirshipBaseTest
@property (nonatomic, strong) UARemoteDataAPIClient *remoteDataAPIClient;
@property (nonatomic, strong) UATestRequestSession *testSession;
@property (nonatomic, copy) NSArray *remoteData;
@end

@implementation UARemoteDataAPIClientTest

- (void)setUp {
    [super setUp];
    self.testSession = [[UATestRequestSession alloc] init];
    self.remoteDataAPIClient = [[UARemoteDataAPIClient alloc] initWithConfig:self.config session:self.testSession];

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
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    self.testSession.data = [self createRemoteDataResponseForPayloads:self.remoteData];
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                            statusCode:200
                                                           HTTPVersion:nil
                                                          headerFields:@{@"Last-Modified":responseLastModified}];


    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:[NSLocale currentLocale]
                                           lastModified:nil
                                      completionHandler:^(UARemoteDataResponse *response, NSError * _Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqual(1, response.payloads.count);
        
        UARemoteDataPayload *remoteData = response.payloads.firstObject;
        XCTAssertEqualObjects(self.remoteData[0][@"type"], remoteData.type);
        XCTAssertEqualObjects(self.remoteData[0][@"data"], remoteData.data);
        
        NSString *timestamp = [UAUtils.ISODateFormatterUTCWithDelimiter stringFromDate:remoteData.timestamp];
        XCTAssertEqualObjects(self.remoteData[0][@"timestamp"], timestamp);

        XCTAssertEqualObjects(responseLastModified, response.lastModified);
        
        id expectedMetadata = @{ @"url": self.testSession.lastRequest.url.absoluteString };
        XCTAssertEqualObjects(expectedMetadata, response.metadata);
        XCTAssertEqualObjects(expectedMetadata, remoteData.metadata);

        [refreshFinished fulfill];
    }];

    // Wait for the test expectations
    [self waitForTestExpectations];

    NSString *expected = [NSString stringWithFormat:@"https://remote-data.urbanairship.com/api/remote-data/app/%@/ios?sdk_version=%@&language=%@&country=%@", self.config.appKey, [UAirshipVersion get], [NSLocale currentLocale].languageCode, [NSLocale currentLocale].countryCode];

    XCTAssertEqualObjects(expected, self.testSession.lastRequest.url.absoluteString);
}

- (void)testFetchRemoteData304 {
    NSString *lastModified = @"2017-01-01T12:00:00";
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:304
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":lastModified}];
    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:[NSLocale currentLocale]
                                           lastModified:lastModified
                                      completionHandler:^(UARemoteDataResponse *response, NSError * _Nullable error) {
        XCTAssertEqual(304, response.status);
        XCTAssertNil(response.lastModified);
        XCTAssertNil(response.payloads);
        XCTAssertNil(error);
        [refreshFinished fulfill];
    }];

    // Wait for the test expectations
    [self waitForTestExpectations];
}

/**
 * Test refresh the remote data when no remote data returned from cloud
 */
- (void)testFetchRemoteDataNoPayloads {
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    self.testSession.data =[self createRemoteDataResponseForPayloads:@[]];
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":responseLastModified}];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:[NSLocale currentLocale]
                                           lastModified:nil
                                      completionHandler:^(UARemoteDataResponse *response, NSError * _Nullable error) {
        XCTAssertEqual(200, response.status);
        XCTAssertEqualObjects(responseLastModified, response.lastModified);
        XCTAssertEqualObjects(@[], response.payloads);
        XCTAssertNil(error);
        [refreshFinished fulfill];
    }];


    // Wait for the test expectations
    [self waitForTestExpectations];
}


- (void)testVersion {
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    self.testSession.data = [self createRemoteDataResponseForPayloads:self.remoteData];
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":responseLastModified}];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:[NSLocale currentLocale]
                                           lastModified:nil
                                      completionHandler:^(UARemoteDataResponse *response, NSError * _Nullable error) {
        [refreshFinished fulfill];
    }];

    [self waitForTestExpectations];

    NSString *expectedVersionQuery = [NSString stringWithFormat:@"sdk_version=%@", [UAirshipVersion get]];

    UARequest *request = self.testSession.lastRequest;
    NSArray *queryComponents = [request.url.query componentsSeparatedByString:@"&"];
    XCTAssertTrue([queryComponents containsObject:expectedVersionQuery]);
}

- (void)testLocale {
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en-01"];
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    self.testSession.data = [self createRemoteDataResponseForPayloads:self.remoteData];
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:@{@"Last-Modified":responseLastModified}];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:locale
                                           lastModified:nil
                                      completionHandler:^(UARemoteDataResponse *response, NSError * _Nullable error) {
        [refreshFinished fulfill];
    }];

    [self waitForTestExpectations];

    NSString *expectedLanguageQuery = @"language=en";
    NSString *expectedCountryQuery = @"country=01";

    UARequest *request = self.testSession.lastRequest;
    NSArray *queryComponents = [request.url.query componentsSeparatedByString:@"&"];
    XCTAssertTrue([queryComponents containsObject:expectedLanguageQuery]);
    XCTAssertTrue([queryComponents containsObject:expectedCountryQuery]);
}

- (void)testLocaleMissingCountry {
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];
    NSString *responseLastModified = @"2017-01-01T12:00:00";
    self.testSession.data = [self createRemoteDataResponseForPayloads:self.remoteData];
    self.testSession.response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""]
                                                            statusCode:200
                                                           HTTPVersion:nil
                                                          headerFields:@{@"Last-Modified":responseLastModified}];

    // Make call
    XCTestExpectation *refreshFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.remoteDataAPIClient fetchRemoteDataWithLocale:locale
                                           lastModified:nil
                                      completionHandler:^(UARemoteDataResponse *response, NSError * _Nullable error) {
        [refreshFinished fulfill];
    }];

    [self waitForTestExpectations];

    NSString *expectedLanguageQuery = @"language=en";

    UARequest *request = self.testSession.lastRequest;
    NSArray *queryComponents = [request.url.query componentsSeparatedByString:@"&"];
    XCTAssertTrue([queryComponents containsObject:expectedLanguageQuery]);
    XCTAssertFalse([request.url.query containsString:@"country="]);
}

- (NSData *)createRemoteDataResponseForPayloads:(NSArray *)payloads {
    NSDictionary *responseDict = @{ @"ok" : @YES,
                                    @"payloads" : payloads
    };

    NSError *error;
    NSData *remoteData = [UAJSONUtils dataWithObject:responseDict options:NSJSONWritingPrettyPrinted error:&error];

    XCTAssertNil(error ,@"Error creating remote data of from array %@: %@", payloads, error.localizedDescription);

    return remoteData;
}

@end

