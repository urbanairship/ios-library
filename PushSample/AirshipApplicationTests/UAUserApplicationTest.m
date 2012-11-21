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


@interface UAUserApplicationTest : SenTestCase

@end

@implementation UAUserApplicationTest

- (void)testUpdateDefaultDeviceToken {
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    int responseCode = 200;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    NSString *testString = @"cats";
    [[NSUserDefaults standardUserDefaults] setValue:testString forKey:kLastUpdatedDeviceTokenKey];
    [UAUser defaultUser].deviceToken = testString;
    [[UAUser defaultUser] performSelector:@selector(updatedDefaultDeviceToken:) withObject:mockRequest];
    STAssertFalse([UAUser defaultUser].deviceTokenHasChanged, @"deviceTokenHasChanged should be NO");
    // Check negative
    mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    responseCode = 500;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    [UAUser defaultUser].deviceToken = @"notCat";
    // Setup deviceTokenHasChanged to YES, with a 500, the hasChagned value should not update
    [UAUser defaultUser].deviceTokenHasChanged = YES;
    [[UAUser defaultUser] performSelector:@selector(updatedDefaultDeviceToken:) withObject:mockRequest];
    STAssertTrue([UAUser defaultUser].deviceTokenHasChanged, @"deviceTokenHasChanged should be YES");
}
@end
