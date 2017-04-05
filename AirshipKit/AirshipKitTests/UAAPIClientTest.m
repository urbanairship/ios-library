/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAAPIClient+Internal.h"
#import "UAConfig.h"

@interface UAAPIClientTest : XCTestCase
@property(nonatomic, strong) UAAPIClient *client;
@property(nonatomic, strong) id mockSession;

@end

@implementation UAAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [OCMockObject niceMockForClass:[UARequestSession class]];
    self.client = [[UAAPIClient alloc] initWithConfig:[UAConfig config] session:self.mockSession];
}

- (void)tearDown {
    [self.mockSession stopMocking];
    [super tearDown];
}

- (void)testCancel {
    [[self.mockSession expect] cancelAllRequests];
    [self.client cancelAllRequests];

    [self.mockSession verify];
}

@end
