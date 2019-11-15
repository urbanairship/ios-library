/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAAPIClient.h"
#import "UARuntimeConfig.h"

@interface UAAPIClientTest : UABaseTest
@property(nonatomic, strong) UAAPIClient *client;
@property(nonatomic, strong) id mockSession;
@end

@implementation UAAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.client = [[UAAPIClient alloc] initWithConfig:self.config session:self.mockSession];
}


- (void)testCancel {
    [[self.mockSession expect] cancelAllRequests];
    [self.client cancelAllRequests];

    [self.mockSession verify];
}

@end
