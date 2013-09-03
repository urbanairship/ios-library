
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UADeviceAPIClient.h"
#import "UAPush.h"
#import "UAPush+Internal.h"

@interface UAPushTest : XCTestCase

@property(nonatomic, strong) id mockDeviceAPIClient;
@property(nonatomic, strong) id mockRegistrationDelegate;
@property(nonatomic, strong) id mockRegistrationObserver;
@end

@implementation UAPushTest

- (void)setUp {
    [super setUp];
    self.mockDeviceAPIClient = [OCMockObject mockForClass:[UADeviceAPIClient class]];
    self.mockRegistrationDelegate = [OCMockObject mockForProtocol:@protocol(UARegistrationDelegate)];
    self.mockRegistrationObserver = [OCMockObject mockForProtocol:@protocol(UARegistrationObserver)];

    [UAPush shared].deviceAPIClient = self.mockDeviceAPIClient;
    [UAPush shared].registrationDelegate = self.mockRegistrationDelegate;

    [[UAPush shared] removeObservers];
    [[UAPush shared] addObserver:self.mockRegistrationObserver];
}

- (void)tearDown {
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testUpdateRegistrationPushEnabledSuccess {

    [[self.mockRegistrationDelegate expect] registerDeviceTokenSucceeded];

    [[self.mockRegistrationObserver expect] registerDeviceTokenSucceeded];

    [[[self.mockDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UADeviceAPIClientSuccessBlock successBlock = (__bridge UADeviceAPIClientSuccessBlock) arg;
        successBlock();
    }] registerWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //enable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}


- (void)testUpdateRegistrationPushEnabledFailure {

    [[self.mockRegistrationDelegate expect] registerDeviceTokenFailed:[OCMArg any]];
    [[self.mockRegistrationObserver expect] registerDeviceTokenFailed:[OCMArg any]];

    [[[self.mockDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UADeviceAPIClientFailureBlock failureBlock = (__bridge UADeviceAPIClientFailureBlock) arg;
        failureBlock(nil);
    }] registerWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //enable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

- (void)testUpdateRegistrationPushDisabledSuccess {
    [[[self.mockDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UADeviceAPIClientSuccessBlock successBlock = (__bridge UADeviceAPIClientSuccessBlock) arg;
        successBlock();
    }] unregisterWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    [[self.mockRegistrationDelegate expect] unregisterDeviceTokenSucceeded];
    [[self.mockRegistrationObserver expect] unregisterDeviceTokenSucceeded];

    //disable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

- (void)testUpdateRegistrationPushDisabledFailure {
    [[[self.mockDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UADeviceAPIClientFailureBlock failureBlock = (__bridge UADeviceAPIClientFailureBlock) arg;
        failureBlock(nil);
    }] unregisterWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    [[self.mockRegistrationDelegate expect] unregisterDeviceTokenFailed:[OCMArg any]];
    [[self.mockRegistrationObserver expect] unregisterDeviceTokenFailed:[OCMArg any]];

    //disable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

@end
