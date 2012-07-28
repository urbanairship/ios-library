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

#import "UAPush.h"
#import "UAPush+Internal.h"
#import "UAirship.h"
#import "UAEvent.h"
#import "UAAnalytics.h"
#import "UAUtils.h"
#import "UA_ASIHTTPRequest.h"
#import "UA_ASIHTTPRequestDelegate.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>
#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>

static BOOL messageReceived = NO;

@interface UAUtils (Test)
+ (void)setMessageReceivedYES;
@end
@implementation UAUtils (Test)
+ (void)setMessageReceivedYES {
    messageReceived = YES;
}
@end

// inteface to delegate callback methods
@interface UAPush (Test)
- (void)registerDeviceTokenSucceeded:(UA_ASIHTTPRequest*)request;
- (void)registerDeviceTokenFailed:(UA_ASIHTTPRequest *)request;
- (void)unRegisterDeviceTokenFailed:(UA_ASIHTTPRequest *)request;
- (void)unRegisterDeviceTokenSucceeded:(UA_ASIHTTPRequest *)request;
@end

@interface UAPushTest : SenTestCase{
    UAPush *push;
    NSString *token;
}

@end



@implementation UAPushTest

- (void)setUp {
    push = [UAPush shared];
    token = @"5824c969fb8498b3ba0f588fb29e9925c867a9b1d0accff5e44537f3f65290e2";
    messageReceived = NO;
    [push removeObservers];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushTagsSettingsKey];
}


- (void)testSetTags {
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"TagTest" ofType:@"plist"];
    NSArray *testTags = [NSArray arrayWithContentsOfFile:path];
    STAssertNotNil(testTags, @"Array of test tags failed to load");
    // Test setTags
    [push setTags:nil];
    [push setTags:testTags];
    STAssertTrue([testTags isEqualToArray:[push tags]], @"Tag arrays should be equal");
}

- (void)testSetAlias {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushAliasSettingsKey];
    [push setAlias:@"cats"];
    STAssertTrue([[push alias] isEqualToString:@"cats"], @"Alias set/get methods are broken");
}

// TODO: keep an eye on the performance of this test, it may be too heavy. 
- (void)testAddTagsToCurrentDevice {
    //There should be no cats in defaults, and addTagToCurrentDevice: becomes addTagsToCurrentDevice
    [[NSUserDefaults standardUserDefaults] setObject:[NSMutableArray array] forKey:UAPushTagsSettingsKey];
    [push addTagToCurrentDevice:@"cats"]; 
    NSArray *tagsWithCats = [push tags];
    STAssertTrue([tagsWithCats containsObject:@"cats"], @"There should be cats in the tags");
    // Test first run
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:UAPushTagsSettingsKey];
    [push addTagToCurrentDevice:@"CATS"];
    tagsWithCats = [push tags];
    STAssertTrue([tagsWithCats containsObject:@"CATS"], @"There should be CATS in the tags");
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"TagTest" ofType:@"plist"];
    // Add a bunch of tags
    NSMutableArray *testTags = [NSMutableArray arrayWithContentsOfFile:path];
    // Add some funky unicode tags
    NSString* funkyString = [NSString stringWithUTF8String:"⇑⇑⇓⇓⇐⇒⇐⇒BABASelectStart==😄❤👍"];
    [testTags addObject:funkyString];
    [push setTags:testTags];
    // Create a sub array of the tags just added, then re add the sub array (lots of duplicates)
    NSArray *subArray = [testTags subarrayWithRange:NSMakeRange(0, 5)];
    [push setTags:subArray];
    NSArray *existingTags = [push tags];
    // Test for duplicates
    __block NSString *firstValue = [testTags objectAtIndex:0];
    NSIndexSet *passingTest = [existingTags indexesOfObjectsPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([(NSString*)obj isEqualToString:firstValue]) {
            return YES;
        }
        return NO;
    }];
    STAssertTrue([passingTest count] == 1, @"There should be exactly one copy of this tag, tag error in UAPush");
}

- (void)testRemoveTags {
    NSArray *someTags = [NSArray arrayWithObjects:@"one", @"two", @"cats", nil];
    [push setTags:someTags];
    [push removeTagsFromCurrentDevice:[NSArray arrayWithObjects:@"one", @"two", nil]];
    STAssertTrue([[push tags] count] == 1, @"There should only be one tag remaining");
    STAssertTrue([@"cats" isEqualToString:[[push tags] objectAtIndex:0]], @"Remaining tag is incorrect");
    [push removeTagFromCurrentDevice:@"cats"];
    STAssertTrue([[push tags] count] == 0, @"Tag array should be empty");
}

// Token and data were pulled from a funcitoning test app.
- (void)testDeviceTokenParsing{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString* path = [bundle pathForResource:@"deviceToken" ofType:@"data"];
    NSError *dataError = nil;
    NSData *deviceTokenData = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&dataError];
    STAssertNil(dataError, @"Error reading device token data %@", dataError.description);
    NSString* actualToken = token;
    [[NSUserDefaults standardUserDefaults] setObject:actualToken forKey:UAPushDeviceTokenDeprecatedSettingsKey];
    [push setDeviceToken:actualToken];
    NSString* parsedToken = [push parseDeviceToken:[deviceTokenData description]];
    STAssertTrue([parsedToken isEqualToString:actualToken], @"ERROR: Device token parsing has failed in UAPush");
    // This method uses a known deprecated method, should be removed in the future. 
    // This should be changed with the completion of LIB-353
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    STAssertFalse(push.deviceTokenHasChanged, @"Device token should not report changed in UAPush");
    STAssertFalse([[UAirship shared] deviceTokenHasChanged], @"Device token should not report changed in UAirhsip");
    NSString* newToken = [actualToken stringByReplacingOccurrencesOfString:@"2" withString:@"4"];
    [push setDeviceToken:newToken];
    STAssertTrue([push.deviceToken isEqualToString:newToken], @"Device token setter has broken");
    STAssertTrue(push.deviceTokenHasChanged, @"Device token should report changed in UAPush");
    STAssertTrue([[UAirship shared] deviceTokenHasChanged], @"Device token should report changed in UAirship");
    #pragma GCC diagnostic warning "-Wdeprecated-declarations"
}

- (void)testTimeZoneSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:nil forKey:UAPushTimeZoneSettingsKey];
    STAssertNil([push timeZone], nil);
    [push setTimeZone:[NSTimeZone localTimeZone]];
    STAssertTrue([[[NSTimeZone localTimeZone] name] isEqualToString:[[push timeZone] name]], nil);
}

- (void)testRegistrationPayload {
    // Setup some payload variables using the methods in UAPush
    NSString *testAlias = @"test_alias";
    NSMutableArray *tags = [NSMutableArray arrayWithObjects:@"tag_one", @"tag_two", nil];
    NSTimeZone* timeZone = [NSTimeZone timeZoneWithName:@"America/Dawson_Creek"]; // Ah, Dawson's creek.....
    NSDate *now = [NSDate date];
    NSDate *oneHour = [NSDate dateWithTimeIntervalSinceNow:360];
    push.canEditTagsFromDevice = NO;
    push.alias = testAlias;
    push.tags = tags;
    [push setQuietTimeFrom:now to:oneHour withTimeZone:timeZone];
    push.autobadgeEnabled = YES;
    // Get a payload, should be NO tag info, the BOOL is set to no
    NSDictionary *payload = [push registrationPayload];
    NSDictionary *quietTimePayload = [payload valueForKey:UAPushQuietTimeJSONKey];
    STAssertNotNil(quietTimePayload, @"UAPushJSON payload is missing quiet time payload");
    NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    NSDateComponents *fromComponents = [calendar components:NSHourCalendarUnit | NSMinuteCalendarUnit fromDate:now];
    NSDateComponents *toComponents = [calendar components:NSHourCalendarUnit | NSMinuteCalendarUnit fromDate:oneHour];
    NSArray *fromHourMinute = [[quietTimePayload valueForKey:UAPushQuietTimeStartJSONKey] componentsSeparatedByString:@":"];
    NSArray *toHourMinute = [[quietTimePayload valueForKey:UAPushQuietTimeEndJSONKey] componentsSeparatedByString:@":"];
    // Quiet times
    STAssertTrue([[timeZone name] isEqualToString:[payload valueForKey:UAPushTimeZoneJSONKey]], nil);
    STAssertTrue(fromComponents.hour == [[fromHourMinute objectAtIndex:0] doubleValue], nil);
    STAssertTrue(fromComponents.minute == [[fromHourMinute objectAtIndex:1] doubleValue], nil);
    STAssertTrue(toComponents.hour == [[toHourMinute objectAtIndex:0] doubleValue], nil);
    STAssertTrue(toComponents.minute == [[toHourMinute objectAtIndex:1] doubleValue], nil);
    // Alias
    STAssertTrue([[payload valueForKey:UAPushAliasJSONKey] isEqualToString:testAlias], nil);
    // Badge number
    STAssertTrue([[payload valueForKey:UAPushBadgeJSONKey] intValue] == 
                 [[UIApplication sharedApplication] applicationIconBadgeNumber], nil);
    // Tags when canEdit is NO
    STAssertNil([payload valueForKey:UAPushMultipleTagsJSONKey], nil);
    // Setup tag editing from the device
    push.canEditTagsFromDevice = YES;
    push.tags = tags;
    payload = [push registrationPayload];
    STAssertTrue([(NSArray*)[payload valueForKey:UAPushMultipleTagsJSONKey] isEqualToArray:tags], nil);

}

//Quiet time was tested above, set test with a nil timezone 
- (void)testQuietTimeWithNilTimeZone {
    [push setQuietTimeFrom:[NSDate date] to:[NSDate dateWithTimeIntervalSinceNow:35] withTimeZone:nil];
    STAssertTrue([[[NSTimeZone defaultTimeZone] name] isEqualToString:[[push timeZone] name]], nil);
}
 
////////////////////////// Block of updateRegistration tests
- (void)testUpdateRegistrationWhenIsRegisteringIsYes {
    push.isRegistering = YES;
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush reject] setIsRegistering:YES];
}

- (void)testUpdateRegisterationWhenInBackground {
    push.isRegistering = NO;
    id mockApplication = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
    UIApplicationState bg = UIApplicationStateBackground;
    [[[mockApplication stub] andReturnValue:OCMOCK_VALUE(bg)] applicationState];
    [push updateRegistration];
    STAssertFalse(push.isRegistering, @"isRegistering should be NO");
}

//- (void)testUpdateRegistrationWhenPushEnabledAndCacheNotStale {
//    push.isRegistering = NO;
//    push.pushEnabled = YES;
//    NSDictionary *cache = @{ @"key" : @"value" };
//    push.registrationPayloadCache = cache;
//    push.pushEnabledPayloadCache = YES;
//    id mockPush = [OCMockObject partialMockForObject:push];
//    [[[mockPush stub] andReturn:cache] registrationPayload];
//    [[mockPush reject] requestToRegisterDeviceTokenWithInfo:OCMOCK_ANY];
//    [push updateRegistration];
//    
//}
//
//- (void)testUpdateRegistrationWhenPushEnabledAndCacheIsStale {
//    push.isRegistering = NO;
//    push.pushEnabled = YES;
//    push.registrationPayloadCache = @{ @"key" : @"StaleValue" };
//    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
//    [[mockRequest expect] startAsynchronous];
//    id mockPush = [OCMockObject partialMockForObject:push];
//    [[[mockPush stub] andReturn:mockRequest] requestToRegisterDeviceTokenWithInfo:OCMOCK_ANY];
//    [push updateRegistration];
//    [mockRequest verify];
//}
//
//- (void)testUpdateRegistrationwhenPushNotEnabledAndCacheIsStale {
//    push.isRegistering = NO;
//    push.pushEnabled = NO;
//    push.registrationPayloadCache = @{ @"key" : @"ADifferentStaleValue" };
//    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushNeedsUnregistering];
//    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
//    [[mockRequest expect] startAsynchronous];
//    id mockPush = [OCMockObject partialMockForObject:push];
//    [[[mockPush stub] andReturn:mockRequest] requestToDeleteDeviceToken];
//    [push updateRegistration];
//    [mockRequest verify];
//    // Throw in extra check for needs unregistering flag
//    mockPush = [OCMockObject partialMockForObject:push];
//    [[mockPush reject] requestToDeleteDeviceToken];
//    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:UAPushNeedsUnregistering];
//    [push updateRegistration];
//}
/////////////////////////

- (void)testRegisterForRemoteNotificationTypes {
    id mockApplication = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
    UIRemoteNotificationType type = UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert;
    [[mockApplication expect] registerForRemoteNotificationTypes:type];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UAPushEnabledSettingsKey];
    [push registerForRemoteNotificationTypes:type];
    [mockApplication verify];
}

- (void)testRegisterDeviceToken {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString* path = [bundle pathForResource:@"deviceToken" ofType:@"data"];
    NSError *dataError = nil;
    NSData *deviceTokenData = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&dataError];
    STAssertNil(dataError, @"Data error in testRegisterDeviceToken %@", dataError.description);
    id mockPush = [OCMockObject partialMockForObject:push];
    id mockAnalytics = [OCMockObject partialMockForObject:[[UAirship shared] analytics]];
    [[mockPush expect] updateRegistration];
    __block id arg = nil;
    void (^getSingleArg)(NSInvocation*) = ^(NSInvocation *invocation){
        [invocation getArgument:&arg atIndex:2];
    };
    [[[mockAnalytics expect] andDo:getSingleArg] addEvent:OCMOCK_ANY];
    [push registerDeviceToken:deviceTokenData];
    STAssertTrue([arg isKindOfClass:[UAEventDeviceRegistration class]], @"UAEventDeviceRegistration not sent during registration");
    [mockPush verify];
}


// Test no registration in background
- (void)testRegisterDeviceTokenInBackground {
    id mockAppliction = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
    id mockPush =  [OCMockObject partialMockForObject:push];
    UIApplicationState state = UIApplicationStateBackground;
    [[[mockAppliction stub] andReturnValue:OCMOCK_VALUE(state)] applicationState];
    [[mockPush reject] requestToRegisterDeviceTokenWithInfo:OCMOCK_ANY];
    [push registerDeviceToken:nil];
}



- (void)testRequestToRegisterDeviceTokenWithInfo {
    UA_ASIHTTPRequest *request = [push requestToRegisterDeviceTokenWithInfo:nil];
    STAssertEqualObjects(push, request.delegate, @"Registration equest delegate not set properly");
    STAssertNil(request.postBody, nil);
    STAssertTrue([request.requestMethod isEqualToString:@"PUT"], nil);
    SEL actualSucceeded = request.didFinishSelector;
    SEL actualFailed = request.didFailSelector;
    SEL correctSucceeded = @selector(registerDeviceTokenSucceeded:);
    SEL correctFailed = @selector(registerDeviceTokenFailed:);
    STAssertTrue(sel_isEqual(actualSucceeded, correctSucceeded), @"Request success selectors incorrect");
    STAssertTrue(sel_isEqual(correctFailed, actualFailed), @"Request fail selectors incorrect");
    NSString *correctServer = [NSString stringWithFormat:@"%@%@%@/", [UAirship shared].server, @"/api/device_tokens/", push.deviceToken];
    NSString *actualServer = request.url.absoluteString;
    STAssertTrue([actualServer isEqualToString:correctServer], @"UA registration API URL incorrect");
    NSDictionary* payload = [push registrationPayload];
    request = [push requestToRegisterDeviceTokenWithInfo:payload];
    NSDictionary* requestHeaders = request.requestHeaders;
    NSString *acceptJSON = [requestHeaders valueForKey:@"Content-Type"];
    STAssertTrue([acceptJSON isEqualToString:@"application/json"], @"Request Content-type incorrect");
    NSError *errorJSON = nil;
    NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:request.postBody options:NSJSONReadingAllowFragments error:&errorJSON];
    STAssertNil(errorJSON, nil);
    STAssertTrue([[payload allKeys] isEqualToArray:[JSON allKeys]], nil);
    STAssertTrue([[payload allValues] isEqualToArray:[JSON allValues]], nil);
}

- (void)testUnregisterDeviceToken {
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] updateRegistration];
    [mockPush unRegisterDeviceToken];
    [mockPush verify];
    STAssertFalse(push.pushEnabled, @"pushEnabled should be NO");
}

- (void)testUnregisterDeviceTokenRequest {
    UA_ASIHTTPRequest *request = [push requestToDeleteDeviceToken];
    NSString *correctServer = [NSString stringWithFormat:@"%@%@%@/", [UAirship shared].server, @"/api/device_tokens/", push.deviceToken];
    NSString *actualServer = request.url.absoluteString;
    STAssertTrue([actualServer isEqualToString:correctServer], @"UA registration API URL incorrect");
    STAssertTrue([request.requestMethod isEqualToString:@"DELETE"], nil);
    STAssertEqualObjects(push, request.delegate, nil);
    BOOL successSelector = sel_isEqual(@selector(unRegisterDeviceTokenSucceeded:), request.didFinishSelector);
    BOOL failSelector = sel_isEqual(@selector(unRegisterDeviceTokenFailed:), request.didFailSelector);
    STAssertTrue(successSelector, nil);
    STAssertTrue(failSelector, nil);
}

- (void)testQuietTimeDisable {
    [push setQuietTimeFrom:[NSDate date] to:[NSDate dateWithTimeIntervalSinceNow:60] withTimeZone:[NSTimeZone defaultTimeZone]];
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] updateRegistration];
    [push disableQuietTime];
    NSDictionary* quietTime = [push quietTime];
    STAssertNil(quietTime, nil);
    [mockPush verify];
}

- (void)testSetBadgeNumber {
    [push setAutobadgeEnabled:NO];
    [push setBadgeNumber:42];
    STAssertTrue(42 == [[UIApplication sharedApplication] applicationIconBadgeNumber], nil);
    [push setDeviceToken:token];
    [push setAutobadgeEnabled:YES];
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] updateRegistration];
    [push setBadgeNumber:7];
    [mockPush verify];
}

- (void)testPushTypeString {
    UIRemoteNotificationType types = (UIRemoteNotificationTypeSound | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert);
    NSString *string = [UAPush pushTypeString:types];
    NSArray *array = [string componentsSeparatedByString:@","];
    // Don't forget the whitespace when separating components
    STAssertTrue([array containsObject:@"Badges"], nil);
    STAssertTrue([array containsObject:@" Alerts"], nil);
    STAssertTrue([array containsObject:@" Sounds"], nil);
}



- (void)testHandleNotificationApplicationState {
    // Setup a notification payload
    NSMutableDictionary* notification = [NSMutableDictionary dictionaryWithCapacity:4];
    NSMutableDictionary* apsDict = [NSMutableDictionary dictionary];
    [push setAutobadgeEnabled:YES];
    [apsDict setValue:@"ALERT" forKey:@"alert"];
    [apsDict setValue:@"42" forKey:@"badge"];
    [apsDict setValue:@"SOUND" forKey:@"sound"];
    [apsDict setValue:@"CUSTOM" forKey:@"custom"];
    [notification setObject:apsDict forKey:@"aps"];
    // Setup a mock object to receive the parsed payload
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    [[mockAnalytics expect] handleNotification:notification];
    // Setup a mock delegate to make sure the proper messages are passed when a notification
    // has been received 
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UAPushNotificationDelegate)];
    [push setDelegate:mockDelegate];
    [[mockDelegate expect] displayNotificationAlert:@"ALERT"];
    [[mockDelegate expect] playNotificationSound:@"SOUND"];
    // Call the handle notification method with our fake payload
    [push handleNotification:notification applicationState:UIApplicationStateActive];
    // Verify the calls were received
    [mockAnalytics verify];
    [mockDelegate verify];
    // Setup a notification that is just a badge update
    [[mockAnalytics stub] handleNotification:notification];
    [push setAutobadgeEnabled:NO];
    [apsDict removeObjectForKey:@"alert"];
    [apsDict removeObjectForKey:@"sound"];
    [[mockDelegate expect] handleBadgeUpdate:42];
    [push handleNotification:notification applicationState:UIApplicationStateActive];
    [mockDelegate verify];
    // Setup localized notification
    [apsDict removeObjectForKey:@"badge"];
    NSDictionary *alertDictionary = [NSDictionary dictionaryWithObject:@"not a" forKey:@"string"];
    [apsDict setObject:alertDictionary forKey:@"alert"];
    [[mockDelegate expect] displayLocalizedNotificationAlert:alertDictionary];
    [push handleNotification:notification applicationState:UIApplicationStateActive];
    [mockDelegate verify];
    // Setup a custom payload to see if it's parsed out correctly
    NSDictionary* customPayload = [NSDictionary dictionaryWithObject:@"PAYLOAD" forKey:@"custom_payload"];
    [notification setObject:customPayload forKey:@"custom_payload"];
    [apsDict removeAllObjects];
    // Setup a block to pull out the arg sent to the handleNotification:withCustomPayload method
    __block NSDictionary *customPayloadArg = nil;
    void (^getSingleArg)(NSInvocation *) = ^(NSInvocation *invocation) 
    {
        [invocation getArgument:&customPayloadArg atIndex:3];
    };
    [[[mockDelegate stub] andDo:getSingleArg]handleNotification:notification withCustomPayload:OCMOCK_ANY];
    [push handleNotification:notification applicationState:UIApplicationStateActive];
    STAssertTrue([[customPayloadArg objectForKey:@"custom_payload"] isEqualToDictionary:customPayload],nil);    
    // Make sure the app passes a background notification message properly
    [[mockDelegate expect] handleBackgroundNotification:notification];
    [push handleNotification:notification applicationState:UIApplicationStateBackground];
    [mockDelegate verify];
}

#pragma mark -
#pragma mark UA API Registration callbacks

- (void)testCacheHasChangedComparedToUserInfo {
    // Rig the cached value with matched settings
    push.registrationPayloadCache = [push registrationPayload];
    push.pushEnabled = NO;
    push.pushEnabledPayloadCache = NO;
    // Get a user info object that would be attached to a UA_HTTPRequest, use the registrationPayload again
    NSDictionary *userInfoDictionary = [push cacheForRequestUserInfoDictionaryUsing:[push registrationPayload]];
    STAssertFalse([push cacheHasChangedComparedToUserInfo:userInfoDictionary], @"chacheHasChanged should be NO");
    push.pushEnabled = YES;
    STAssertTrue([push cacheHasChangedComparedToUserInfo:userInfoDictionary], @"cacheHasChanged should be YES");
    push.pushEnabled = NO;
    userInfoDictionary = [push cacheForRequestUserInfoDictionaryUsing:[NSDictionary dictionaryWithObject:@"cat" forKey:@"key"]];
    STAssertTrue([push cacheHasChangedComparedToUserInfo:userInfoDictionary], @"cacheHasChanged should be YES");
    
}

// This test covers the basic error case, the workflow where the response from the server is NOT a 500
- (void)testRegisterDeviceTokenFailed {
    id mockPush = [OCMockObject partialMockForObject:push];
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    BOOL yes = YES;
    [[[mockPush stub] andReturnValue:OCMOCK_VALUE(yes)] shouldRetryRequest:mockRequest];
    [[mockPush expect] shouldRetryRequest:mockRequest];
    [push registerDeviceTokenFailed:mockRequest];
    STAssertFalse(push.isRegistering, @"isRegistering should be NO");
    
}

- (void)testRegisterDeviceTokenSucceeded {
    // Non 200,201 response
    id mockPush = [OCMockObject partialMockForObject:push];
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    int responseCode = 399;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    [push registerDeviceTokenSucceeded:mockRequest];
    [mockPush verify];
    //
    // 200 response
    mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    responseCode = 200;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    [[mockPush expect] cacheSuccessfulUserInfo:OCMOCK_ANY];
    BOOL yes = YES;
    [[[mockPush stub] andReturnValue:OCMOCK_VALUE(yes)] cacheHasChangedComparedToUserInfo:OCMOCK_ANY];
    [[mockPush expect] updateRegistration];
    [push registerDeviceTokenSucceeded:mockRequest];
    [mockPush verify];
    STAssertFalse(push.isRegistering, @"isRegistering should be NO");
    
}

- (void)testUnregisterDeviceTokenFailed {
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    id mockPush = [OCMockObject partialMockForObject:push];
    BOOL yes = YES;
    [[[mockPush expect] andReturnValue:OCMOCK_VALUE(yes)] shouldRetryRequest:mockRequest];
    [[mockPush expect] scheduleRetryForRequest:mockRequest];
    [push unRegisterDeviceTokenFailed:mockRequest];
    [mockPush verify];
}

- (void)testUnregisterDeviceTokenSucceeded {
    // API returns 200 (failure)
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    int statusCode = 200;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(statusCode)] responseStatusCode];
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] unRegisterDeviceTokenFailed:mockRequest];
    [push unRegisterDeviceTokenSucceeded:mockRequest];
    [mockPush verify];
    //
    // API returns 204, successful unregistration
    mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    statusCode = 204;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(statusCode)] responseStatusCode];
    [[mockPush expect] cacheSuccessfulUserInfo:OCMOCK_ANY];
    BOOL no = NO;
    [[[mockPush stub] andReturnValue:OCMOCK_VALUE(no)] cacheHasChangedComparedToUserInfo:OCMOCK_ANY];
    [push unRegisterDeviceTokenSucceeded:mockRequest];
    STAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:UAPushNeedsUnregistering], @"UAPushNeedsUnregistering should be NO on successful unregistration");
    STAssertFalse(push.isRegistering, @"isRegistering should be NO");
    [mockPush verify];
}

- (void)testShouldRetryReqeust {
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    push.retryOnConnectionError = NO;
    STAssertFalse([push shouldRetryRequest:mockRequest], @"shouldRetryRequest should return NO");
    push.retryOnConnectionError = YES;
    NSError *error = [NSError errorWithDomain:@"test" code:42 userInfo:nil];
    [[[mockRequest stub] andReturn:error] error];
    STAssertTrue([push shouldRetryRequest:mockRequest], @"shouldRetryRequest should return YES when an error exists");
    mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    int responseCode = 501;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    STAssertTrue([push shouldRetryRequest:mockRequest], @"shouldRetryRequest should return YES whith statusCode 500 <= statusCode <= 599");
    mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    responseCode = 499;
    [[[mockRequest stub] andReturnValue:OCMOCK_VALUE(responseCode)] responseStatusCode];
    STAssertFalse([push shouldRetryRequest:mockRequest], @"shouldRetryRequest should return NO whith statusCode not in 500 range");
}

- (void)testScheduleRetryForRequest {
    push.isRegistering = YES;
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    id mockPush = [OCMockObject partialMockForObject:push];
    int one = 1;
    [[[mockPush stub] andReturnValue:OCMOCK_VALUE(one)] registrationRetryDelay];
    void (^markCalled)(NSInvocation *) = ^(NSInvocation *invocation) {
        messageReceived = YES;
    };
    [[[mockPush expect] andDo:markCalled] updateRegistration];
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:5];
    [push scheduleRetryForRequest:mockRequest];
    while (!messageReceived) {
        // Just keep moving the run loop date forward slightly, so the exit is quick
        [[NSRunLoop currentRunLoop] runMode:[[NSRunLoop currentRunLoop] currentMode] beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
        if([timeout timeIntervalSinceNow] < 0.0) {
            break;
        }
    }
    STAssertFalse(push.isRegistering, @"isRegistering should be NO");
    STAssertTrue(messageReceived, @"push should have received updateRegistration call");
    [mockPush verify];
}

#pragma mark -
#pragma mark Deprecated Method tests
// Who knows when they'll actually go away?

#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

- (void)testUpdateAliasUpdateTags {
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] updateRegistration];
    [push updateAlias:@"cat"];
    STAssertTrue([@"cat" isEqualToString:push.alias],nil);
    [mockPush verify];
    NSMutableArray *tags = [NSMutableArray arrayWithObjects:@"one cat", @"two cat", nil];
    [[mockPush expect] updateRegistration];
    [push updateTags:tags];
    STAssertTrue([tags isEqualToArray:push.tags], nil);
    [mockPush verify];
}

- (void)testEnableAutobadge {
    [push enableAutobadge:NO];
    STAssertFalse(push.autobadgeEnabled, nil);
    [push enableAutobadge:YES];
    STAssertTrue(push.autobadgeEnabled, nil);
}

- (void)testRegisterDeviceTokenWithExtraInfo {
    id mockRequest = [OCMockObject niceMockForClass:[UA_ASIHTTPRequest class]];
    id mockPush = [OCMockObject partialMockForObject:push];
    id mockAnalytics = [OCMockObject partialMockForObject:[UAirship shared].analytics];
    [[[mockPush stub] andReturn:mockRequest] requestToRegisterDeviceTokenWithInfo:OCMOCK_ANY];
    [[mockRequest expect] startAsynchronous];
    [[mockAnalytics expect] addEvent:OCMOCK_ANY];
    [push registerDeviceTokenWithExtraInfo:nil];
    [mockRequest verify];
    [mockAnalytics verify];
    mockAnalytics = nil;
}

- (void)testRegisterDeviceTokenWithAlias {
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] setRetryOnConnectionError:NO];
    [[mockPush expect] setDeviceToken:OCMOCK_ANY];
    [[mockPush expect] setAlias:OCMOCK_ANY];
    [[mockPush expect] updateRegistration];
    [push registerDeviceToken:[NSData data] withAlias:@"alias"];
    [mockPush verify];
}

#pragma GCC diagnostic warning "-Wdeprecated-declarations"




@end
