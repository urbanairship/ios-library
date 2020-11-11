/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAAPIClient.h"
#import "UARuntimeConfig.h"

@interface UAAPIClientTest : UAAirshipBaseTest
@property(nonatomic, strong) UAAPIClient *client;
@property(nonatomic, strong) id mockSession;
@property(nonatomic, strong) id mockQueue;
@end

@implementation UAAPIClientTest

- (void)setUp {
    [super setUp];
    self.mockSession = [self mockForClass:[UARequestSession class]];
    self.mockQueue = [self mockForClass:[NSOperationQueue class]];
    self.client = [[UAAPIClient alloc] initWithConfig:self.config session:self.mockSession queue:self.mockQueue];
}

- (void)testCancel {
    [[self.mockQueue expect] cancelAllOperations];
    [self.client cancelAllRequests];
    [self.mockQueue verify];
}

@end
