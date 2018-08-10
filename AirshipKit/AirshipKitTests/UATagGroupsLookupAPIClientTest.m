/* Copyright 2018 Urban Airship and Contributors */

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

    self.mockConfig = [OCMockObject niceMockForClass:[UAConfig class]];
    self.mockSession = [OCMockObject niceMockForClass:[UARequestSession class]];
    self.mockSessionClass = OCMClassMock([UARequestSession class]);
    [[[self.mockSessionClass stub] andReturn:self.mockSession] sessionWithConfig:OCMOCK_ANY];

    self.client = [UATagGroupsLookupAPIClient clientWithConfig:self.mockConfig session:self.mockSession];
}

- (void)tearDown {
    [self.mockSession stopMocking];
    [self.mockConfig stopMocking];
    [self.mockSessionClass stopMocking];

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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *lookupFinished = [self expectationWithDescription:@"Refresh finished"];

    UATagGroups *requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    [self.client lookupTagGroupsWithChannelID:@"channel-id" requestedTagGroups:requestedTagGroups
                               cachedResponse:nil
                            completionHandler:^(UATagGroupsLookupResponse *lookupResponse) {
                                XCTAssertEqual(lookupResponse.status, 200);
                                XCTAssertEqualObjects(lookupResponse.tagGroups, requestedTagGroups);
                                XCTAssertEqualObjects(lookupResponse.lastModifiedTimestamp, @"2018-03-02T22:56:09");
                                [lookupFinished fulfill];
                            }];

    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockSession verify];
    }];
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
        [invocation getArgument:&arg atIndex:4];
        UARequestCompletionHandler completionHandler = (__bridge UARequestCompletionHandler)arg;
        completionHandler(responseData, response, nil);
    }] dataTaskWithRequest:OCMOCK_ANY retryWhere:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    XCTestExpectation *lookupFinished = [self expectationWithDescription:@"Refresh finished"];

    UATagGroups *requestedTagGroups = [UATagGroups tagGroupsWithTags:@{@"foo" : @[@"bar", @"baz"]}];

    UATagGroupsLookupResponse *cachedResponse = [UATagGroupsLookupResponse responseWithTagGroups:requestedTagGroups
                                                                                          status:200
                                                                           lastModifiedTimestamp:@"2018-03-02T22:56:09"];

    [self.client lookupTagGroupsWithChannelID:@"channel-id" requestedTagGroups:requestedTagGroups
                               cachedResponse:cachedResponse
                            completionHandler:^(UATagGroupsLookupResponse *lookupResponse) {
                                XCTAssertEqual(lookupResponse.status, 200);
                                XCTAssertEqual(lookupResponse, cachedResponse);
                                [lookupFinished fulfill];
                            }];

    // Wait for the test expectations
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        [self.mockSession verify];
    }];
}

@end
