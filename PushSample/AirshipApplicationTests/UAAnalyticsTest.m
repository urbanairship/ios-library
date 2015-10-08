/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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
#import <XCTest/XCTest.h>

#import "UAConfig.h"
#import "UAAnalyticsDBManager.h"
#import "UAEvent.h"
#import "UALocationEvent.h"
#import "UAAnalytics+Internal.h"
#import "UAirship+Internal.h"
#import "UALocationTestUtils.h"
#import "UAEventPushReceived.h"
#import "UAEventAppForeground.h"
#import "UAEventAppInit.h"
#import "UAEventAppBackground.h"
#import "UAPreferenceDataStore.h"

/* This class involves lots of async calls to the web
 Care should be taken to mock out responses and calls, race conditions
 can cause tests to fail, these conditions would not occur in normal app 
 usage */


@interface UAAnalyticsTest : XCTestCase {
  @private
    UAAnalytics *_analytics;
    UAPreferenceDataStore *_dataStore;
}

@end

@implementation UAAnalyticsTest


- (void)setUp {
    UAConfig *config = [[UAConfig alloc] init];
    _dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:@"analytics.tests"];
    _analytics = [UAAnalytics analyticsWithConfig:config dataStore:_dataStore];

    // Use verbose logging so all the logs show up during tests
    config.developmentLogLevel = UALogLevelTrace;

    [UAirship shared].analytics = _analytics;
}

- (void)tearDown {
    [_dataStore removeAll];
    _dataStore = nil;
    _analytics = nil;
}

- (void)testLastSendTimeGetSetMethods {
    // setup a date with a random number to make sure values aren't stale
    NSDate *testDate = [NSDate dateWithTimeIntervalSinceNow:arc4random() % 9999];
    [_analytics setLastSendTime:testDate];
    NSDate *analyticsDateFromDefaults = [_analytics lastSendTime];
    NSTimeInterval timeBetweenDates = [testDate timeIntervalSinceDate:analyticsDateFromDefaults];

    // Date formatting for string representation truncates the date value to the nearest second
    // hence, expect to be off by a second
    XCTAssertEqualWithAccuracy(timeBetweenDates, (NSTimeInterval)0, 1);
}

- (void)testHandleNotification {

    id mockAnalytics = [OCMockObject partialMockForObject:_analytics];
    __block id arg = nil;

    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        __unsafe_unretained id unsafeArg = nil;
        [invocation getArgument:&unsafeArg atIndex:2];
        arg = unsafeArg;
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [_analytics handleNotification:[NSDictionary dictionaryWithObject:@"stuff" forKey:@"key"] inApplicationState:UIApplicationStateActive];
    XCTAssertNotNil(arg);
    XCTAssertTrue([arg isKindOfClass:[UAEventPushReceived class]]);
    [mockAnalytics stopMocking];
}

//// Refactor this next time it's changed

/*
 * Ensure that an app entering the foreground resets state and sets
 * the flag that will insert a flag on didBecomeActive.
 */
- (void)testEnterForeground {
    id mockAnalytics = [OCMockObject partialMockForObject:_analytics];

    //set up event capture
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation *) = ^(NSInvocation *invocation){
        __unsafe_unretained id unsafeArg = nil;
        [invocation getArgument:&unsafeArg atIndex:2];
        arg = unsafeArg;
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    
    [_analytics enterForeground];
    
    XCTAssertTrue(_analytics.isEnteringForeground, @"`enterForeground` should set `isEnteringForeground_` to YES");
    XCTAssertNil(arg, @"`enterForeground` should not insert an event");
    
    [mockAnalytics verify];
    [mockAnalytics stopMocking];
}

- (void)testDidBecomeActiveAfterForeground {
    id mockAnalytics = [OCMockObject partialMockForObject:_analytics];
    
    __block int foregroundCount = 0;
    __block int eventCount = 0;
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        __unsafe_unretained id unsafeArg = nil;
        [invocation getArgument:&unsafeArg atIndex:2];
        
        if ([unsafeArg isKindOfClass:[UAEventAppForeground class]]) {
            foregroundCount++;
        }
        
        eventCount++;
        arg = unsafeArg;
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    
    _analytics.isEnteringForeground = YES;
    [_analytics didBecomeActive];
    
    XCTAssertFalse(_analytics.isEnteringForeground, @"`didBecomeActive` should set `isEnteringForeground_` to NO");
    

    XCTAssertEqual(foregroundCount, 1, @"One foreground event inserted.");
    XCTAssertEqual(eventCount, 1, @"Only the one should be insterted.");

    [mockAnalytics verify];
    [mockAnalytics stopMocking];
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
    
    NSString *incomingPushID = @"the_push_id";
    
    //count events and grab the push ID
    __block int foregroundCount = 0;
    __block int eventCount = 0;
    __block NSString *eventPushID = nil;
    void (^getSingleArg)(NSInvocation *) = ^(NSInvocation *invocation){
        
        id __unsafe_unretained arg = nil;
        [invocation getArgument:&arg atIndex:2];

        
        if ([arg isKindOfClass:[UAEventAppForeground class]]) {
            foregroundCount++;
            
            // save the push id for later
            UAEventAppForeground *fgEvent = (UAEventAppForeground *)arg;
            eventPushID = [fgEvent.data objectForKey:@"push_id"];
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
    [[UAirship shared].analytics handleNotification:[NSDictionary dictionaryWithObject:incomingPushID forKey:@"_"] inApplicationState:UIApplicationStateInactive];
    
    //now the app is active, according to NSNotificationCenter
    [[UAirship shared].analytics didBecomeActive];
    
    XCTAssertFalse([UAirship shared].analytics.isEnteringForeground, @"`didBecomeActive` should set `isEnteringForeground_` to NO");
        
    XCTAssertEqual(foregroundCount, 1, @"One foreground event should be inserted.");
    XCTAssertEqual(eventCount, 1, @"Only the one should be insterted.");
    XCTAssertTrue([incomingPushID isEqualToString:eventPushID], @"The incoming push ID is not included in the event payload.");
    
    [mockAnalytics verify];
    [mockAnalytics stopMocking];
    [mockApplication stopMocking];
}


- (void)testEnterBackground {
    id mockAnalytics = [OCMockObject partialMockForObject:_analytics];
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        __unsafe_unretained id unsafeArg = nil;
        [invocation getArgument:&unsafeArg atIndex:2];
        arg = unsafeArg;
    };
    [[[mockAnalytics expect] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [_analytics enterBackground];
    XCTAssertTrue([arg isKindOfClass:[UAEventAppBackground class]], @"Enter background should fire UAEventAppBackground");
    [mockAnalytics verify];
    [mockAnalytics stopMocking];
}


- (void)testDidBecomeActive {
    id mockAnalytics = [OCMockObject partialMockForObject:_analytics];
    
    //set up event capture
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        __unsafe_unretained id unsafeArg = nil;
        [invocation getArgument:&unsafeArg atIndex:2];
        arg = unsafeArg;
    };
    [[[mockAnalytics stub] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    
    [_analytics didBecomeActive];
    
    XCTAssertFalse(_analytics.isEnteringForeground, @"`enterForeground` should set `isEnteringForeground_` to NO");
    
    [mockAnalytics stopMocking];
}

// This test is not comprehensive for this method, as the method needs refactoring.
- (void)testPrepareEventsForUpload {
    UAEventAppForeground *appEvent = [UAEventAppForeground event];

    // If the events database is empty, everything crashes
    XCTAssertNotNil(appEvent);
    // Remember, the NSUserPreferences are in an unknown state in every test, so reset
    // preferences if the methods under test rely on them
    _analytics.maxTotalDBSize = kMaxTotalDBSizeBytes;
    _analytics.maxBatchSize = kMaxBatchSizeBytes;
    [_analytics addEvent:appEvent];
    NSArray* events = [_analytics prepareEventsForUpload];
    XCTAssertTrue([events isKindOfClass:[NSArray class]]);
    XCTAssertTrue([events count] > 0);
}

- (void)testAnalyticsIsThreadSafe {
    UAAnalytics *airshipAnalytics = [[UAirship shared] analytics];

    __block BOOL threadTestEnded = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_queue_t testQueue = dispatch_queue_create("com.urbanairship.analyticsThreadsafeTest", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t testGroup = dispatch_group_create();

    dispatch_group_async(testGroup, testQueue, ^{
        UALocationEvent *event = [UALocationEvent significantChangeLocationEventWithLocation:[UALocationTestUtils testLocationPDX] providerType:@"testUpdate"];
        int random = 0;
        for (int i = 0; i < 10; i++) {
            random = arc4random() % 2;
            if (random == 0) {
                dispatch_group_async(testGroup, dispatch_get_main_queue(), ^{
                    if (!threadTestEnded) { //if the test is over, just don't do anything
                        NSLog(@"Added test event on main thread");
                        [airshipAnalytics addEvent:event];
                    }
                });
            } else {
                NSLog(@"Added test event on a background thread");
                [airshipAnalytics addEvent:event];
            }
        }

        // OK we're done. Signal on the main queue AFTER all the other stuff is dispatched.
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_semaphore_signal(semaphore);

        });

    });

    // Wait for main queue block to execute
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:5.0];// Give these things 5 seconds to complete
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW)  && [timeoutDate timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    threadTestEnded = YES;

    UAAnalyticsDBManager *analyticsDb = airshipAnalytics.analyticsDBManager;

    NSArray *bunchOevents = [analyticsDb getEvents:100];
    __block BOOL testFail = YES;
    [bunchOevents enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        __block BOOL isNull = NO;
        if ([obj isKindOfClass:[NSDictionary class]]) {
            [(NSDictionary*)obj enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (key == NULL || obj == NULL) {
                    isNull = YES;
                    *stop = YES;
                }
            }];
        }
        if (isNull == YES) {
            testFail = YES;
            *stop = YES;
        }
        else {
            testFail = NO;
        }
    }];
    XCTAssertFalse(testFail, @"NULL value in UAAnalyticsDB, check threading issues");
}


@end
