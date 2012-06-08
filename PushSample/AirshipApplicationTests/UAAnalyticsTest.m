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
#import "UALocationEvent.h"
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

/*
 * Ensure that an app entering the foreground resets state and sets
 * the flag that will insert a flag on didBecomeActive.
 */
- (void)testEnterForeground {
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[mockAnalytics expect] invalidateBackgroundTask];
    [[mockAnalytics expect] setupSendTimer:X_UA_MIN_BATCH_INTERVAL];
    
    //set up event capture
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation *) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    
    [analytics enterForeground];
    
    STAssertTrue(analytics.isEnteringForeground, @"`enterForeground` should set `isEnteringForeground_` to YES");
    STAssertNil(arg, @"`enterForeground` should not insert an event");
    
    [mockAnalytics verify];
}

- (void)testDidBecomeActiveAfterForeground {
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[mockAnalytics expect] refreshSessionWhenNetworkChanged];
    [[mockAnalytics expect] refreshSessionWhenActive];
    
    __block int foregroundCount = 0;
    __block int activeCount = 0;
    __block int eventCount = 0;
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        
        [invocation getArgument:&arg atIndex:2];
        if ([arg isKindOfClass:[UAEventAppActive class]]) {
            activeCount++;
        }
        
        if ([arg isKindOfClass:[UAEventAppForeground class]]) {
            foregroundCount++;
        }
        
        eventCount++;
        
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    
    analytics.isEnteringForeground = YES;
    [analytics didBecomeActive];
    
    STAssertFalse(analytics.isEnteringForeground, @"`didBecomeActive` should set `isEnteringForeground_` to NO");
    
    STAssertTrue([arg isKindOfClass:[UAEventAppActive class]] , @"didBecomeActive should fire UAEventAppActive");
    
    STAssertEquals(foregroundCount, 1, @"One foreground event inserted.");
    STAssertEquals(activeCount, 1, @"One active event inserted.");
    STAssertEquals(eventCount, 2, @"Two total events inserted.");
    
    [mockAnalytics verify];
}

/*
 * This is a larger test, but the intent is to test the full foreground from notification flow
 */
- (void)testForegroundFromPush {
    //We have to mock the singleton analytics rather than the analytics ivar
    //so we can test analytics insert end to end - the event generation code
    //uses the singleton version, so if we want to pull the right session into
    //an event, we have to use that one.
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    
    NSString *incomingPushId = @"the_push_id";
    
    //count events and grab the push ID
    __block int foregroundCount = 0;
    __block int activeCount = 0;
    __block int eventCount = 0;
    __block id arg = nil;
    __block NSString *eventPushId = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        
        [invocation getArgument:&arg atIndex:2];
        if ([arg isKindOfClass:[UAEventAppActive class]]) {
            activeCount++;
        }
        
        if ([arg isKindOfClass:[UAEventAppForeground class]]) {
            foregroundCount++;
            
            // save the push id for later
            UAEventAppForeground *fgEvent = (UAEventAppForeground *)arg;
            eventPushId = [fgEvent.data objectForKey:@"push_id"];
        }
        
        eventCount++;
        
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    
    // We're in the background
    id mockApplication = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
    UIApplicationState state = UIApplicationStateBackground;
    [[[mockApplication stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];
    
    [[UAirship shared].analytics enterForeground];// fired from NSNotificationCenter
    
    //mock a notification - the "_" id is all that matters - we don't need an aps payload
    //this value is passed in through the app delegate's didReceiveRemoteNotification method
    [[UAirship shared].analytics handleNotification:[NSDictionary dictionaryWithObject:incomingPushId forKey:@"_"]];
    
    //now the app is active, according to NSNotificationCenter
    [[UAirship shared].analytics didBecomeActive];
    
    STAssertFalse([UAirship shared].analytics.isEnteringForeground, @"`didBecomeActive` should set `isEnteringForeground_` to NO");
    
    STAssertTrue([arg isKindOfClass:[UAEventAppActive class]] , @"didBecomeActive should fire UAEventAppActive");
    
    STAssertEquals(foregroundCount, 1, @"One foreground event should be inserted.");
    STAssertEquals(activeCount, 1, @"One active event should be inserted.");
    STAssertEquals(eventCount, 2, @"Two total events should be inserted.");
    STAssertTrue([incomingPushId isEqualToString:eventPushId], @"The incoming push ID is not included in the event payload.");
    
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
    
    //set up event capture
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    
    [analytics didBecomeActive];
    
    STAssertFalse(analytics.isEnteringForeground, @"`enterForeground` should set `isEnteringForeground_` to NO");
    
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
    [analytics restoreFromDefault];
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    STAssertTrue(analytics.x_ua_max_total == [[defaults valueForKey:@"X-UA-Max-Total"] intValue], nil);
    STAssertTrue(analytics.x_ua_max_batch == [[defaults valueForKey:@"X-UA-Max-Batch"] intValue], nil);
    STAssertTrue(analytics.x_ua_max_wait == [[defaults valueForKey:@"X-UA-Max-Wait"] intValue], nil);
    STAssertTrue(analytics.x_ua_min_batch_interval == [[defaults valueForKey:@"X-UA-Min-Batch-Interval"] intValue], nil);
}

- (void)testSaveDefault  {
    analytics.x_ua_max_batch = 7;
    analytics.x_ua_max_total = 7;
    analytics.x_ua_max_wait = 7;
    analytics.x_ua_min_batch_interval = 7; 
    [analytics saveDefault];
    NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    STAssertTrue([[defaults valueForKey:@"X-UA-Max-Total"] intValue] == 7, nil);
    STAssertTrue([[defaults valueForKey:@"X-UA-Max-Batch"] intValue] == 7, nil);
    STAssertTrue([[defaults valueForKey:@"X-UA-Max-Wait"] intValue] == 7, nil);
    STAssertTrue([[defaults valueForKey:@"X-UA-Min-Batch-Interval"] intValue] == 7, nil);

}

- (void)testAddEvent {
    // Should add an event in the foreground
    UAEventAppActive *event = [[[UAEventAppActive alloc] init] autorelease];
    id mockDBManager = [OCMockObject partialMockForObject:[UAAnalyticsDBManager shared]];
    [[mockDBManager expect] addEvent:event withSession:analytics.session];
    analytics.oldestEventTime = 0;
    [analytics addEvent:event];
    [mockDBManager verify];
    //
    // Should not send an event in the background when not location event
    STAssertTrue(analytics.oldestEventTime == [event.time doubleValue], nil);
    [[mockDBManager expect] addEvent:event withSession:analytics.session];
    id mockApplication = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
    UIApplicationState state = UIApplicationStateBackground;
    [[[mockApplication stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];
    analytics.sendBackgroundTask = UIBackgroundTaskInvalid;
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[mockAnalytics reject] send];
    [analytics addEvent:event];
    [mockAnalytics verify];
    //
    // Should send a location event in the background
    mockAnalytics = [OCMockObject partialMockForObject:analytics];
    UALocationEvent *locationEvent = [[[UALocationEvent alloc] initWithLocationContext:nil] autorelease];
    [[mockDBManager expect] addEvent:locationEvent withSession:analytics.session];
    [[mockAnalytics expect] send];
    [analytics addEvent:locationEvent];
    [mockAnalytics verify];
}

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
    [headers setValue:[NSNumber numberWithInt:5] forKey:@"X-Ua-Max-Total"];
    [headers setValue:[NSNumber numberWithInt:5] forKey:@"X-Ua-Max-Batch"];
    [headers setValue:[NSNumber numberWithInt:X_UA_MAX_WAIT - 1] forKey:@"X-Ua-Max-Wait"];
    [headers setValue:[NSNumber numberWithInt:X_UA_MIN_BATCH_INTERVAL + 1] forKey:@"X-Ua-Min-Batch-Interval"];
    mockResponse = [OCMockObject niceMockForClass:[NSHTTPURLResponse class]];
    mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[mockAnalytics expect] saveDefault];
    [[[mockResponse stub] andReturn:headers] allHeaderFields];
    [analytics updateAnalyticsParametersWithHeaderValues:mockResponse];
    // There is some math here, account for these in the test
    STAssertEquals(analytics.x_ua_max_total, 5 * 1024, nil);
    STAssertEquals(analytics.x_ua_max_batch, 5 * 1024, nil);
    //
    STAssertEquals(analytics.x_ua_max_wait, X_UA_MAX_WAIT - 1, nil);
    STAssertEquals(analytics.x_ua_min_batch_interval, X_UA_MIN_BATCH_INTERVAL + 1, nil);
}

- (void)testRequestDidFail {
    id mockRequest = [OCMockObject niceMockForClass:[UAHTTPRequest class]];
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    [[mockAnalytics expect] invalidateBackgroundTask];
    analytics.connection = [UAHTTPConnection connectionWithRequest:mockRequest];
    [analytics requestDidFail:mockRequest];
    [mockAnalytics verify];
    STAssertNil(analytics.connection, nil);
}

- (void)testShouldSendAnalyticsCore {
    analytics.server = nil;
    STAssertFalse([analytics shouldSendAnalytics], nil);
    analytics.server = @"cats";
    analytics.connection = [UAHTTPConnection connectionWithRequest:nil];
    STAssertFalse([analytics shouldSendAnalytics], nil);
    analytics.connection = nil;
    id mockDBManger = [OCMockObject partialMockForObject:[UAAnalyticsDBManager shared]];
    NSInteger zero = 0;
    [[[mockDBManger stub] andReturnValue:OCMOCK_VALUE(zero)] eventCount];
    STAssertFalse([analytics shouldSendAnalytics], nil);
    analytics.databaseSize = 0;
    mockDBManger = [OCMockObject partialMockForObject:[UAAnalyticsDBManager shared]];
    NSInteger five = 5;
    [[[mockDBManger stub] andReturnValue:OCMOCK_VALUE(five)] eventCount];
    STAssertFalse([analytics shouldSendAnalytics], nil);
}

- (void)testShouldSendAnalyticsBackgroundLogic {
    analytics.server = @"cats";
    analytics.connection = nil;
    id mockDBManger = [OCMockObject partialMockForObject:[UAAnalyticsDBManager shared]];
    mockDBManger = [OCMockObject partialMockForObject:[UAAnalyticsDBManager shared]];
    NSInteger five = 5;
    [[[mockDBManger stub] andReturnValue:OCMOCK_VALUE(five)] eventCount];
    id mockApplication = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
    UIApplicationState state = UIApplicationStateBackground;
    [[[mockApplication stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];
    analytics.sendBackgroundTask = 9;
    STAssertTrue([analytics shouldSendAnalytics], nil);
    analytics.sendBackgroundTask = UIBackgroundTaskInvalid;
    analytics.lastSendTime = [NSDate distantPast];
    STAssertTrue([analytics shouldSendAnalytics], nil);
    analytics.lastSendTime = [NSDate date];
    STAssertFalse([analytics shouldSendAnalytics], nil);
    mockApplication = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
    state = UIApplicationStateActive;
    [[[mockApplication stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];
    STAssertTrue([analytics shouldSendAnalytics], nil);
}

- (void)testSend {
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    id mockAnalytics = [OCMockObject partialMockForObject:analytics];
    id mockConnection = [OCMockObject niceMockForClass:[UAHTTPConnection class]];
    analytics.connection = mockConnection;
    // Intercept setConnection to prevent the mock that was just setup from being 
    // replaced during execution of the send method
    [[mockAnalytics stub] setConnection:OCMOCK_ANY];
    [[mockConnection expect] setDelegate:analytics];
    // Casting this object prevents a compiler warning
    [(UAHTTPConnection*)[mockConnection expect] start];
    BOOL yes = YES;
    [[[mockAnalytics stub] andReturnValue:OCMOCK_VALUE(yes)] shouldSendAnalytics];
    UAHTTPRequest *request = [analytics analyticsRequest];
    id mockRequest = [OCMockObject partialMockForObject:request];
    [[[mockRequest stub] andDo:getSingleArg] setUserInfo:OCMOCK_ANY];
    [[[mockAnalytics stub] andReturn:request] analyticsRequest];
    NSArray* data = [NSArray arrayWithObjects:@"one", @"two", nil];
    [[[mockAnalytics stub] andReturn:data] prepareEventsForUpload];
    [analytics send];
    [mockConnection verify];
    STAssertEqualObjects(arg, data, @"UAAnalytics send method not populating request userInfo object with correct data");
}

// This test is not comprehensive for this method, as the method needs refactoring.
- (void)testPrepareEventsForUpload {
    UAEventAppForeground *appEvent = [[[UAEventAppForeground alloc] init] autorelease];
    // If the events database is empty, everything crashes
    STAssertNotNil(appEvent, nil);
    // Remember, the NSUserPreferences are in an unknown state in every test, so reset
    // preferences if the methods under test rely on them
    analytics.x_ua_max_total = X_UA_MAX_TOTAL;
    analytics.x_ua_max_batch = X_UA_MAX_BATCH;
    [analytics addEvent:appEvent];
    NSArray* events = [analytics prepareEventsForUpload];
    STAssertTrue([events isKindOfClass:[NSArray class]], nil);
    STAssertTrue([events count] > 0, nil);
}

- (void)testSetSendInterval {
    STAssertEquals(UAAnalyticsFirstBatchUploadInterval, (int)analytics.sendTimer.timeInterval, nil);
    STAssertTrue([analytics.sendTimer isValid], nil);
    int newVal = 42;
    analytics.x_ua_min_batch_interval = 5;
    analytics.x_ua_max_wait = 50;
    analytics.sendInterval = newVal;
    STAssertTrue([analytics.sendTimer isValid], nil);
    STAssertEquals(42, (int)analytics.sendTimer.timeInterval, nil);
    STAssertEquals(42, analytics.sendInterval, nil);
}


@end
