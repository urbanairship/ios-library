
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

    //inject the mock device API client
    [UAPush shared].deviceAPIClient = self.mockDeviceAPIClient;
    //add our mock registration delegate
    [UAPush shared].registrationDelegate = self.mockRegistrationDelegate;

    //remove all existing observers before adding our mock registration observer,
    //so we don't end up with angry zombie mocks between cases
    [[UAPush shared] removeObservers];
    [[UAPush shared] addObserver:self.mockRegistrationObserver];
}

- (void)tearDown {
    [self.mockDeviceAPIClient stopMocking];
    [self.mockRegistrationDelegate stopMocking];
    [self.mockRegistrationObserver stopMocking];
    [super tearDown];
}

//when push is enabled, updateRegistration should result in a registerDeviceTokenSucceeded callback
//to the observer and delegate on success
- (void)testUpdateRegistrationPushEnabledSuccess {

    //the device api client should receive a registration call.
    //in this case, we'll call the success block immediately.
    [[[self.mockDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UADeviceAPIClientSuccessBlock successBlock = (__bridge UADeviceAPIClientSuccessBlock) arg;
        successBlock();
    }] registerWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //we should get success callbacks on both the delegate and observer
    [[self.mockRegistrationDelegate expect] registerDeviceTokenSucceeded];
    [[self.mockRegistrationObserver expect] registerDeviceTokenSucceeded];

    //enable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

//when push is enabled, updateRegistration should result in a registerDeviceTokenFailed callback
//to the observer and delegate on failure
- (void)testUpdateRegistrationPushEnabledFailure {

    //the device api client should receive an registration call.
    //in this case, we'll call the failure block immediately.
    [[[self.mockDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UADeviceAPIClientFailureBlock failureBlock = (__bridge UADeviceAPIClientFailureBlock) arg;
        //passing nil here instead of the usual UAHTTPRequest argument for convenience
        failureBlock(nil);
    }] registerWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //we should get failure callbacks on both the delegate and observer
    [[self.mockRegistrationDelegate expect] registerDeviceTokenFailed:[OCMArg any]];
    [[self.mockRegistrationObserver expect] registerDeviceTokenFailed:[OCMArg any]];

    //enable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

//when push is disabled, updateRegistration should result in a unregisterDeviceTokenSucceeded callback
//to the observer and delegate on success
- (void)testUpdateRegistrationPushDisabledSuccess {

    //the device api client should receive an unregistration call.
    //in this case, we'll call the success block immediately.
    [[[self.mockDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UADeviceAPIClientSuccessBlock successBlock = (__bridge UADeviceAPIClientSuccessBlock) arg;
        successBlock();
    }] unregisterWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //we should get success callbacks on both the delegate and observer
    [[self.mockRegistrationDelegate expect] unregisterDeviceTokenSucceeded];
    [[self.mockRegistrationObserver expect] unregisterDeviceTokenSucceeded];

    //disable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

//when push is disabled, updateRegistration should result in a unregisterDeviceTokenFailed callback
//to the observer and delegate on failure
- (void)testUpdateRegistrationPushDisabledFailure {

    //the device api client should receive an unregistration call.
    //in this case, we'll call the failure block immediately.
    [[[self.mockDeviceAPIClient expect] andDo:^(NSInvocation *invocation){
        void *arg;
        [invocation getArgument:&arg atIndex:4];
        UADeviceAPIClientFailureBlock failureBlock = (__bridge UADeviceAPIClientFailureBlock) arg;
        //passing nil here instead of the usual UAHTTPRequest argument for convenience
        failureBlock(nil);
    }] unregisterWithData:[OCMArg any] onSuccess:[OCMArg any] onFailure:[OCMArg any] forcefully:NO];

    //we should get failure callbacks on both the delegate and observer
    [[self.mockRegistrationDelegate expect] unregisterDeviceTokenFailed:[OCMArg any]];
    [[self.mockRegistrationObserver expect] unregisterDeviceTokenFailed:[OCMArg any]];

    //disable push without calling custom setter
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushEnabledSettingsKey];
    [[UAPush shared] updateRegistration];
}

@end
