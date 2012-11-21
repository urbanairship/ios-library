/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>

#import "UA_ASIHTTPRequest.h"
#import "UAUser.h"
#import "UAUser+Internal.h"
#import "UAPush.h"


@interface UAUserApplicationTest : SenTestCase

@end

@implementation UAUserApplicationTest

/** Test that the device token is only cached on a 200 response from the UAUser updatedDefaultDeviceToken */
- (void)testUpdateDefaultDeviceToken {
    // Set a device token and a mock request to return a 200. The cached token
    // should reflect the current value in [UAPush defaultPush].deviceToken
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    int responseCode = 200;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    NSString *testString = @"cats";
    [UAUser defaultUser].deviceToken = testString;
    // This should update NSUserDefaults with the test string
    [[UAUser defaultUser] performSelector:@selector(updatedDefaultDeviceToken:) withObject:mockRequest];
    NSString *persistedDeviceToken = [[NSUserDefaults standardUserDefaults] stringForKey:kLastUpdatedDeviceTokenKey];
    STAssertTrue([testString isEqualToString:persistedDeviceToken], @"%@ should be %@", kLastUpdatedDeviceTokenKey, testString);
    ////
    // Check that the cached device token is not changed when the request returns an  non 200 value
    mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    responseCode = 500;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    [[UAUser defaultUser] performSelector:@selector(updatedDefaultDeviceToken:) withObject:mockRequest];
    testString = @"notCats";
    [UAUser defaultUser].deviceToken = testString;
    persistedDeviceToken = [[NSUserDefaults standardUserDefaults] stringForKey:kLastUpdatedDeviceTokenKey];
    STAssertFalse([testString isEqualToString:persistedDeviceToken], @"%@ should not be %@",persistedDeviceToken , testString);
}

/** Test that a change  in device token is properly captured */
- (void)testDeviceTokenChangeRecording {
    // Setup scenario where token doesn't change
    NSString *token = @"cats";
    // Stub a response from UAPush
    id mockPush = [OCMockObject partialMockForObject:[UAPush shared]];
    [[[mockPush stub] andReturn:token] deviceToken];
    // Set matching default
    [[NSUserDefaults standardUserDefaults] setValue:token forKey:kLastUpdatedDeviceTokenKey];
    // Stub out the network call in UAUser so it doesn't slow down the test
    id mockUser = [OCMockObject partialMockForObject:[UAUser defaultUser]];
    [[mockUser stub] updateUserInfo:OCMOCK_ANY withDelegate:OCMOCK_ANY finish:@selector(updatedDefaultDeviceToken:)fail:@selector(requestWentWrong:)];
    // Check for match
    [[UAUser defaultUser] updateDefaultDeviceToken];
    STAssertFalse([UAUser defaultUser].deviceTokenHasChanged, @"deviceTokenHasChanged should be NO");
    // Check for different token
    [[NSUserDefaults standardUserDefaults] setValue:@"notCats" forKey:kLastUpdatedDeviceTokenKey];
    [[UAUser defaultUser] updateDefaultDeviceToken];
    STAssertTrue([UAUser defaultUser].deviceTokenHasChanged, @"deviceTokenHasChanged should be YES");
    
}
@end
