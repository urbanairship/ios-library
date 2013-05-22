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

#import "UAUser.h"
#import "UAUser+Internal.h"

#import "UAPush.h"
#import "UAPush+Internal.h"

@interface UAUserApplicationTest : SenTestCase

@end

@implementation UAUserApplicationTest

/** Test that the device token is only cached on a 200 response from the UAUser updatedDefaultDeviceToken */
- (void)testUpdatedDefaultDeviceToken {
    /*
    // Set a device token and a mock request to return a 200. The cached token
    // should reflect the current value in [UAPush defaultPush].deviceToken
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    int responseCode = 200;
    [[[mockRequest expect] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    // Build a JSON payload for UAUser to parse a token out of.
    NSString *testString = @"cats";
    NSData *payloadJson = [self payloadWithTokenValue:testString];
    [[[mockRequest expect] andReturn:payloadJson] postBody];
    
    // This should update NSUserDefaults with the token out of the above payload
    [[UAUser defaultUser] performSelector:@selector(updatedDefaultDeviceToken:) withObject:mockRequest];
    NSString *persistedDeviceToken = [[NSUserDefaults standardUserDefaults] stringForKey:kLastUpdatedDeviceTokenKey];
    STAssertTrue([testString isEqualToString:persistedDeviceToken], @"%@ should be %@", kLastUpdatedDeviceTokenKey, testString);
    [mockRequest verify];
    ////
    // Check that the cached device token is not changed when the request returns an  non 200 value
    // Prep defaults
    [[NSUserDefaults standardUserDefaults] setValue:testString forKey:kLastUpdatedDeviceTokenKey];
    // Prep mock response
    mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    responseCode = 500;
    // Setup a payload with a value that is different than the cached value, then assert that the value is unchanged
    // with a 500 response
    [[[mockRequest expect] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    // Shouldn't be reading the payload
    [[[mockRequest reject] andReturn:payloadJson] postBody];
    // Call method
    [[UAUser defaultUser] performSelector:@selector(updatedDefaultDeviceToken:) withObject:mockRequest];
    // Check results
    [mockRequest verify];
    persistedDeviceToken = [[NSUserDefaults standardUserDefaults] stringForKey:kLastUpdatedDeviceTokenKey];
    // Check that token remains unchanged
    STAssertTrue([testString isEqualToString:persistedDeviceToken], @"%@ should not be %@",persistedDeviceToken , testString); */
}

- (NSData*)payloadWithTokenValue:(NSString*)token {
    NSDictionary *payload = @{@"device_tokens" :@{@"add" : @[token]}};
    NSError *jsonError = nil;
    NSData *payloadJson = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:&jsonError];
    STAssertNil(jsonError, @"Error generating test JSON");
    return payloadJson;
}

/** Test that a change  in device token is properly calculated */
- (void)testDeviceTokenChange {
    [[UAPush shared] setDeviceToken:@"cats"];
    [[UAUser defaultUser] setServerDeviceToken:@"notCats"];
    STAssertTrue([[UAUser defaultUser]deviceTokenHasChanged], @"deviceTokenHasChanged should be YES");
    [[UAUser defaultUser] setServerDeviceToken:@"cats"];
    STAssertFalse([[UAUser defaultUser] deviceTokenHasChanged], @"deviceTokenHasChanged should be NO");
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kLastUpdatedDeviceTokenKey];
    STAssertTrue([[UAUser defaultUser] deviceTokenHasChanged], nil);
}

/** Test that the device token actually sets a lowercase string in NSUserDefaults for the appropriate key */
- (void)testGetSetDeviceToken {
    NSString *testString = @"cAts In a hat";
    NSString *sameTestLowercase = [testString lowercaseString];
    [[UAUser defaultUser] setServerDeviceToken:testString];
    STAssertTrue([[[NSUserDefaults standardUserDefaults] stringForKey:kLastUpdatedDeviceTokenKey] isEqualToString:sameTestLowercase], @"Value for kLastUpdatedDeviceTokenKey in UAUser not set properly, or not lowercased");
    NSString *targetString = @"cat";
    [[NSUserDefaults standardUserDefaults] setValue:targetString forKey:kLastUpdatedDeviceTokenKey];
    STAssertTrue([[[UAUser defaultUser] serverDeviceToken] isEqualToString:targetString], @"UAUser defaultUser device token get not returning proper value" );
}
@end
