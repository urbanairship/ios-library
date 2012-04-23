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
#import "UAAnalyticsDBManager.h"
#import "UAEvent.h"
#import "UAAnalytics+Internal.h"
#import "UAirship.h"

/* This class involves lots of async calls to the web
 Care should be taken to mock out responses and calls, race conditions
 can cause tests to fail, these conditions would not occur in normal app 
 usage */


@interface UAAnalyticsTest : SenTestCase {
    UAAnalytics *analytics;
}

@end

@implementation UAAnalyticsTest


- (void)setUp {
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] 
                                                                      forKey:UAAnalyticsOptionsLoggingKey];
    analytics = [[UAAnalytics alloc] initWithOptions:options];
}

- (void)tearDown {
    [analytics invalidate];
    RELEASE(analytics);
//    [analytics autorelease];
//    analytics = nil;
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
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [analytics handleNotification:[NSDictionary dictionaryWithObject:@"stuff" forKey:@"key"]];
    STAssertNotNil(arg, nil);
    STAssertTrue([arg isKindOfClass:[UAEventPushReceived class]], nil);    
}

//// Refactor this next time it's changed
- (void)testEnterForeground {
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[mockAnalytics expect] refreshSessionWhenNetworkChanged];
    [[mockAnalytics expect]  refreshSessionWhenActive];
    [[mockAnalytics expect]  invalidateBackgroundTask];
    [[mockAnalytics expect]  setupSendTimer:X_UA_MIN_BATCH_INTERVAL];
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [analytics enterForeground];
    STAssertTrue([arg isKindOfClass:[UAEventAppForeground class]], @"Enter foreground should fire UAEventAppForeground");
    [mockAnalytics verify];
}
- (void)testEnterBackground {
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[mockAnalytics expect] send];
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics expect] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [analytics enterBackground];
    STAssertTrue([arg isKindOfClass:[UAEventAppBackground class]], @"Enter background should fire UAEventAppBackground");
    STAssertTrue(analytics.sendBackgroundTask != UIBackgroundTaskInvalid, @"A background task should exist");
    STAssertFalse([analytics.sendTimer isValid], @"sendTimer should be invalid");
    [mockAnalytics verify];
}

- (void)testInvalidateBackgroundTask {
    analytics.sendBackgroundTask = 5.0;
    [analytics invalidateBackgroundTask];
    STAssertTrue(analytics.sendBackgroundTask == UIBackgroundTaskInvalid, nil);
}

- (void)testDidBecomeActive {
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [analytics didBecomeActive];
    STAssertTrue([arg isKindOfClass:[UAEventAppActive class]] , @"didBecomeActive should fire UAEventAppActive");
}

- (void)testWillResignActive {
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [analytics willResignActive];
    STAssertTrue([arg isKindOfClass:[UAEventAppInactive class]], @"willResignActive should fire UAEventAppInactive");
}

- (void)testRestoreFromDefault {
    analytics.x_ua_max_batch = 0;
    analytics.x_ua_max_total = 0;
    analytics.x_ua_max_wait = 0;
    analytics.x_ua_min_batch_interval = 0;
    [[NSUserDefaults standardUserDefaults] setValue:nil forKey:UAAnalyticsOptionsLastLocationSendTime];
    [analytics restoreFromDefault];
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    STAssertTrue(analytics.x_ua_max_total == [[defaults valueForKey:@"X-UA-Max-Total"] intValue], nil);
    STAssertTrue(analytics.x_ua_max_batch == [[defaults valueForKey:@"X-UA-Max-Batch"] intValue], nil);
    STAssertTrue(analytics.x_ua_max_wait == [[defaults valueForKey:@"X-UA-Max-Wait"] intValue], nil);
    /* The code establishes the current date as the last send date when NSUserDefaults returns nil
     This is a cheap two step check, writing this date too and from user defaults occurs elsewhere */
    STAssertNotNil([[NSUserDefaults standardUserDefaults] valueForKey:UAAnalyticsOptionsLastLocationSendTime], nil);
    STAssertEqualsWithAccuracy([[NSDate date] timeIntervalSinceDate:analytics.lastSendTime], (NSTimeInterval)0.0, 1, nil);
}

- (void)testSaveDefault  {
    analytics.x_ua_max_batch = 7;
    analytics.x_ua_max_total = 7;
    analytics.x_ua_max_wait = 7;
    analytics.x_ua_min_batch_interval = 7; 
    analytics.lastSendTime = nil;
    [analytics saveDefault];
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    STAssertTrue([[defaults valueForKey:@"X-UA-Max-Total"] intValue] == 7, nil);
    STAssertTrue([[defaults valueForKey:@"X-UA-Max-Batch"] intValue] == 7, nil);
    STAssertTrue([[defaults valueForKey:@"X-UA-Max-Wait"] intValue] == 7, nil);
    STAssertTrue([[defaults valueForKey:@"X-UA-Min-Batch-Interval"] intValue] == 7, nil);
    STAssertNotNil([[NSUserDefaults standardUserDefaults] valueForKey:UAAnalyticsOptionsLastLocationSendTime], nil);
    STAssertEqualsWithAccuracy([[NSDate date] timeIntervalSinceDate:analytics.lastSendTime], (NSTimeInterval)0.0, 1, nil);
}

- (void)testAddEvent {
    UAEventAppActive *event = [[[UAEventAppActive alloc] init] autorelease];
    id mockDBManager = [OCMockObject partialMockForObject:[UAAnalyticsDBManager shared]];
    [[mockDBManager expect] addEvent:event withSession:analytics.session];
    analytics.oldestEventTime = 0;
    [analytics addEvent:event];
    [mockDBManager verify];
    STAssertTrue(analytics.oldestEventTime == [event.time doubleValue], nil);
}

// TODO: Add test to make sure sending something that's not an array doesn't cras
- (void)testRequestDidSucceed {
    id mockDBManager = [OCMockObject partialMockForObject:[UAAnalyticsDBManager shared]];
    id mockRequest = [OCMockObject niceMockForClass:[UAHTTPRequest class]];
    NSArray *info = [NSArray arrayWithObject:@"one"];
    [[[mockRequest stub] andReturn:info] userInfo];
    id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];
    NSInteger code = 200;
    [[[mockResponse stub] andReturnValue:OCMOCK_VALUE(code)] statusCode];
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[mockAnalytics expect] updateAnalyticsParametersWithHeaderValues:mockResponse];
    [[mockAnalytics expect] resetEventsDatabaseStatus];
    [[mockAnalytics expect] invalidateBackgroundTask];
    [[mockDBManager expect] deleteEvents:info];
    [analytics requestDidSucceed:mockRequest response:mockResponse responseData:nil];
    [mockAnalytics verify];
    [mockDBManager verify];
    [mockResponse verify];
    [mockRequest verify];
    STAssertEqualsWithAccuracy([[NSDate date] timeIntervalSinceDate:analytics.lastSendTime], (NSTimeInterval)0, 2, nil);
}

- (void)testUpdateAnalyticsParameters {
    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithCapacity:4];
    // Hit all the if statements that prevent values from changing
    [headers setValue:[NSNumber numberWithInt:X_UA_MAX_TOTAL + 1] forKey:@"X-Ua-Max-Total"];
    [headers setValue:[NSNumber numberWithInt:X_UA_MAX_BATCH + 1] forKey:@"X-Ua-Max-Batch"];
    [headers setValue:[NSNumber numberWithInt:X_UA_MAX_WAIT + 1] forKey:@"X-Ua-Max-Wait"];
    [headers setValue:[NSNumber numberWithInt:X_UA_MIN_BATCH_INTERVAL - 1] forKey:@"X-Ua-Min-Batch-Interval"];
    id mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[mockAnalytics expect] saveDefault];
    [[[mockResponse stub] andReturn:headers] allHeaderFields];
    [analytics updateAnalyticsParametersWithHeaderValues:mockResponse];
    STAssertEquals(analytics.x_ua_max_total, X_UA_MAX_TOTAL, nil);
    STAssertEquals(analytics.x_ua_max_batch, X_UA_MAX_BATCH, nil);
    STAssertEquals(analytics.x_ua_max_wait, X_UA_MAX_WAIT, nil);
    STAssertEquals(analytics.x_ua_min_batch_interval, X_UA_MIN_BATCH_INTERVAL, nil);
    [mockAnalytics verify];
    // end the ifs
    // hit all the elses
    headers = [NSMutableDictionary dictionaryWithCapacity:4];
    [headers setValue:[NSNumber numberWithInt:X_UA_MAX_TOTAL - 1] forKey:@"X-Ua-Max-Total"];
    [headers setValue:[NSNumber numberWithInt:X_UA_MAX_BATCH - 1] forKey:@"X-Ua-Max-Batch"];
    [headers setValue:[NSNumber numberWithInt:X_UA_MAX_WAIT - 1] forKey:@"X-Ua-Max-Wait"];
    [headers setValue:[NSNumber numberWithInt:X_UA_MIN_BATCH_INTERVAL + 1] forKey:@"X-Ua-Min-Batch-Interval"];
    [[[mockResponse stub] andReturn:headers] allHeaderFields];
    [analytics updateAnalyticsParametersWithHeaderValues:mockResponse];
    STAssertEquals(analytics.x_ua_max_total, X_UA_MAX_TOTAL - 1, nil);
    STAssertEquals(analytics.x_ua_max_batch, X_UA_MAX_BATCH - 1 , nil);
    STAssertEquals(analytics.x_ua_max_wait, X_UA_MAX_WAIT - 1, nil);
    STAssertEquals(analytics.x_ua_min_batch_interval, X_UA_MIN_BATCH_INTERVAL + 1, nil);
    
}











@end
