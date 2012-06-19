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

#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>

@interface UAPushTest : SenTestCase{
    UAPush *push;
}

@end



@implementation UAPushTest

- (void)setUp {
    push = [UAPush shared];
}

- (void)testInit {
//    STAssertTrue(push.)
}

// Token and data were pulled from a funcitoning test app.
- (void)testDeviceTokenParsing{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString* path = [bundle pathForResource:@"deviceToken" ofType:@"data"];
    NSError *dataError = nil;
    NSData *deviceTokenData = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&dataError];
    STAssertNil(dataError, @"Error reading device token data %@", dataError.description);
    NSString* actualToken = @"5824c969fb8498b3ba0f588fb29e9925c867a9b1d0accff5e44537f3f65290e2";
    [[NSUserDefaults standardUserDefaults] setObject:actualToken forKey:UAPushDeviceTokenSettingsKey];
    [push setDeviceToken:actualToken];
    NSString* parsedToken = [push parseDeviceToken:[deviceTokenData description]];
    STAssertTrue([parsedToken isEqualToString:actualToken], @"ERROR: Device token parsing has failed in UAPush");
    STAssertFalse(push.deviceTokenHasChanged, @"Device token should not report changed");
    NSString* newToken = [actualToken stringByReplacingOccurrencesOfString:@"2" withString:@"4"];
    [push setDeviceToken:newToken];
    STAssertTrue([push.deviceToken isEqualToString:newToken], @"Device token setter has broken");
    STAssertTrue(push.deviceTokenHasChanged, @"Device token should report changed");
}

- (void)testTimeZoneSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:nil forKey:UAPushTimeZoneSettingsKey];
    NSTimeZone *timeZone = [push timeZone];
    STAssertTrue(timeZone.secondsFromGMT == [NSTimeZone localTimeZone].secondsFromGMT, @"Default time zone in UAPush is incorrect");
    [push setTimeZone:nil]; // this should set the default time zone in NSUserDefaults
    NSDictionary* timeZoneSettings = [defaults dictionaryForKey:UAPushTimeZoneSettingsKey];
    STAssertNotNil(timeZoneSettings, @"Error in time zone settings dictionary in UAPush");  
    NSTimeZone *defaultTimeZone = [NSTimeZone defaultTimeZone];
    BOOL isDaylight = [[timeZoneSettings valueForKey:UAPushTimeZoneIsDaylightSavingsKey] boolValue];
    NSInteger offset = [[timeZoneSettings valueForKey:UAPushTimeZoneOffesetKey] intValue];
    STAssertTrue(isDaylight == defaultTimeZone.isDaylightSavingTime, nil);
    STAssertTrue(offset == defaultTimeZone.secondsFromGMT, nil);
}

- (void)testRegistrationPayload {
    NSString *testAlias = @"test_alias";
    NSMutableArray *tags = [NSMutableArray arrayWithObjects:@"tag_one", @"tag_two", nil];
    NSTimeZone* timeZone = [NSTimeZone timeZoneWithName:@"America/Dawson_Creek"]; // Ah, Dawson's creek.....
    NSDate *now = [NSDate date];
    NSDate *oneHour = [NSDate dateWithTimeIntervalSinceNow:360];
    [push setAlias:testAlias];
    [push setTags:tags];
    [push setQuietTimeFrom:now to:oneHour withTimeZone:timeZone];
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
    // Tags
    STAssertTrue([tags isEqualToArray:[payload valueForKey:UAPushMultipleTagsJSONKey]], nil);
}

- (void)testTimeZoneFallback {
    NSArray *timeZoneObjects = [NSArray arrayWithObjects:[NSNumber numberWithBool:NO], @"junk", [NSNumber numberWithInt:-25200], nil];
    NSArray *timeZoneKeys = [NSArray arrayWithObjects:UAPushTimeZoneIsDaylightSavingsKey, UAPushTimeZoneNameKey, UAPushTimeZoneOffesetKey, nil];
    NSDictionary *timeZoneData = [NSDictionary dictionaryWithObjects:timeZoneObjects forKeys:timeZoneKeys];
    [[NSUserDefaults standardUserDefaults] setValue:timeZoneData forKey:UAPushTimeZoneSettingsKey];
    NSTimeZone* timeZone = [push timeZone];
    STAssertTrue(timeZone.secondsFromGMT == [[timeZoneObjects objectAtIndex:2] intValue], nil);
}

- (void)testUpdateRegistrationLogic {
    [push setPushEnabled:YES];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString* path = [bundle pathForResource:@"deviceToken" ofType:@"data"];
    NSError *dataError = nil;
    NSData *deviceTokenData = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&dataError];
    STAssertNil(dataError, @"Error reading device token data %@", dataError.description);
    ;
    push.notificationTypes = UIRemoteNotificationTypeSound | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert;
    id mockPush = [OCMockObject partialMockForObject:push];
    [[mockPush expect] registerForRemoteNotificationTypes:push.notificationTypes];
    [push updateRegistration];
    [mockPush verify];
    
}





@end
