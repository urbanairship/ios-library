/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UATagGroupsLookupAPIClient+Internal.h"

@interface UATagGroupsLookupAPIClientTest : UABaseTest
@property (nonatomic, strong) UATagGroupsLookupAPIClient *client;
@property (nonatomic, strong) id mockConfig;
@property (nonatomic, strong) id mockSession;
@property (nonatomic, strong) id mockSessionClass;
@end

@implementation UATagGroupsLookupAPIClientTest

- (void)setUp {
    [super setUp];

    self.mockConfig = [self mockForClass:[UARuntimeConfig class]];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.mockSessionClass = [self mockForClass:[UARequestSession class]];
    [[[self.mockSessionClass stub] andReturn:self.mockSession] sessionWithConfig:OCMOCK_ANY];

    self.client = [UATagGroupsLookupAPIClient clientWithConfig:self.mockConfig session:self.mockSession];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testLookupTagGroups {

    NSDictionary *responseDict = @{ @"last_modified": @"2018-03-02T22:56:09",
                                    @"tag_groups": @{@"foo" : @[@"bar", @"baz"]}
    };

    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseDict options:NSJSONWritingPrettyPrinted error:nil];

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *lookupFinished = [self expectationWithDescription:@"Refresh finished"];

    UATagGroups *requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    [self.client lookupTagGroupsWithChannelID:@"channel-id"
                           requestedTagGroups:requestedTagGroups
                               cachedResponse:nil
                            completionHandler:^(UATagGroupsLookupResponse *lookupResponse) {
        XCTAssertEqual(lookupResponse.status, 200);
        XCTAssertEqualObjects(lookupResponse.tagGroups, requestedTagGroups);
        XCTAssertEqualObjects(lookupResponse.lastModifiedTimestamp, @"2018-03-02T22:56:09");
        [lookupFinished fulfill];
    }];

    // Wait for the test expectations
    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testLookupTagGroupsCached {

    NSDictionary *responseDict = @{ @"last_modified": @"2018-03-02T22:56:09",
                                    @"tag_groups": @{@"foo" : @[@"bar", @"baz"]}
    };

    NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseDict options:NSJSONWritingPrettyPrinted error:nil];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@""] statusCode:200 HTTPVersion:nil headerFields:nil];

    // Stub the session to return the response
    [[[self.mockSession stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *lookupFinished = [self expectationWithDescription:@"Refresh finished"];

    UATagGroups *requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    UATagGroupsLookupResponse *cachedResponse = [UATagGroupsLookupResponse responseWithTagGroups:requestedTagGroups
                                                                                          status:200
                                                                           lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    [self.client lookupTagGroupsWithChannelID:@"channel-id"
                           requestedTagGroups:requestedTagGroups
                               cachedResponse:cachedResponse
                            completionHandler:^(UATagGroupsLookupResponse *lookupResponse) {
        XCTAssertEqual(lookupResponse.status, 200);
        XCTAssertEqual(lookupResponse, cachedResponse);
        [lookupFinished fulfill];
    }];

    // Wait for the test expectations
    [self waitForTestExpectations];
    [self.mockSession verify];
}

- (void)testURLAndPayloadSent {
    NSDictionary *expectedPayload =     @{
        @"channel_id" : @"channel-id",
        @"device_type" : @"ios",
        @"tag_groups" : @{
                @"foo" : @[
                        @"bar",
                        @"baz"
                ]
        }
    };

    NSString *expectedLookupBaseURL = @"https://go.urbanairship.com";
    NSString *expectedLookupEndpoint = @"/api/channel-tags-lookup";
    NSString *expectedLookupURL = [NSString stringWithFormat:@"%@%@",expectedLookupBaseURL, expectedLookupEndpoint];

    NSData *expectedPayloadData = [NSJSONSerialization dataWithJSONObject:expectedPayload options:NSJSONWritingPrettyPrinted error:nil];

    [[[self.mockConfig expect] andReturn:expectedLookupBaseURL] deviceAPIURL];

    // Stub the session to inspect the request
    [[[self.mockSession expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UARequest *request = (__bridge UARequest *)arg;

        [invocation getArgument:&arg atIndex:3];
        UAHTTPRequestCompletionHandler completionHandler = (__bridge UAHTTPRequestCompletionHandler)arg;

        XCTAssertEqualObjects([request.URL absoluteString], expectedLookupURL);
        XCTAssertEqualObjects(request.body, expectedPayloadData);
        completionHandler(nil, nil, nil);
    }] performHTTPRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    UATagGroups *requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    XCTestExpectation *lookupFinished = [self expectationWithDescription:@"Refresh finished"];
    [self.client lookupTagGroupsWithChannelID:@"channel-id"
                           requestedTagGroups:requestedTagGroups
                               cachedResponse:nil
                            completionHandler:^(UATagGroupsLookupResponse *lookupResponse) {
        [lookupFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockConfig verify];
    [self.mockSession verify];
}

@end

