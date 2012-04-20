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

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import <SenTestingKit/SenTestingKit.h>
#import "UAAnalytics.h"
#import "UAEvent.h"
#import "UAAnalytics+Internal.h"
#import "UAirship.h"


@interface UAAnalyticsTest : SenTestCase {
    UAAnalytics *analytics;
}

@end

@implementation UAAnalyticsTest


- (void)setUp {
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] 
                                                                      forKey:UAAnalyticsOptionsLoggingKey];
    analytics = [[UAAnalytics alloc] initWithOptions:options];
//    arg = nil;
//    getSingleArg = ^(NSInvocation *invocation){
//        [invocation getArgument:&arg atIndex:2];
//    };
}

- (void)tearDown {
    [analytics invalidate];
    RELEASE(analytics);
}

- (void)testLastSendTimeGetSetMethods {
    // setup a date with a random number to make sure values aren't stale
    NSDate *testDate = [NSDate dateWithTimeIntervalSinceNow:arc4random() % 9999];
    [analytics setLastSendTime:testDate];
    NSDate* analyticsDateFromDefaults = [analytics lastSendTime];
    NSTimeInterval timeBetweenDates = [testDate timeIntervalSinceDate:analyticsDateFromDefaults];
    // Date formatting for string representation truncates the date value to the nearest second
    // hence, expect to be off by a second
    STAssertEqualsWithAccuracy(timeBetweenDates, (NSTimeInterval)0, 1, nil);
}

- (void)testHandleNotification {
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    __block id arg;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [analytics handleNotification:[NSDictionary dictionaryWithObject:@"stuff" forKey:@"key"]];
    STAssertNotNil(arg, nil);
    STAssertTrue([arg isKindOfClass:[UAEventPushReceived class]], nil);    
}

- (void)testEnterForeground {
    [analytics enterForeground];
}


@end
