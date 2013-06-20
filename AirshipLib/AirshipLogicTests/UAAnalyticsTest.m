/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.
 
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

#import "UAConfig.h"
#import "UAAnalytics+Internal.h"
#import "UAHTTPConnection+Internal.h"
#import "UAAnalyticsTest.h"
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAKeychainUtils.h"


@interface UAAnalyticsTest()
@property(nonatomic, retain) UAAnalytics *analytics;
@end

@implementation UAAnalyticsTest


- (void)setUp {
    [super setUp];
    
    id mockedKeyChainClass = [OCMockObject mockForClass:[UAKeychainUtils class]];
    [[[mockedKeyChainClass stub] andReturn:@"some-device-id"] getDeviceID];
    
    UAConfig *config = [[[UAConfig alloc] init] autorelease];
    self.analytics = [[UAAnalytics alloc] initWithConfig:config];
 }

- (void)tearDown {
    [super tearDown];
    RELEASE(self.analytics);
}

- (void)testRequestTimezoneHeader {
    [self setTimeZone:@"America/New_York"];
    
    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    STAssertEqualObjects([headers objectForKey:@"X-UA-Timezone"], @"America/New_York", @"Wrong timezone in event headers");
}

- (void)testRequestLocaleHeadersFullCode {
    [self setCurrentLocale:@"en_US_POSIX"];

    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    STAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Language"], @"en", @"Wrong local language code in event headers");
    STAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Country"],  @"US", @"Wrong local country code in event headers");
    STAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Variant"],  @"POSIX", @"Wrong local variant in event headers");
}

- (void)testAnalyticRequestLocationHeadersPartialCode {
    [self setCurrentLocale:@"de"];
    
    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    STAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Language"], @"de", @"Wrong local language code in event headers");
    STAssertNil([headers objectForKey:@"X-UA-Locale-Country"], @"Wrong local country code in event headers");
    STAssertNil([headers objectForKey:@"X-UA-Locale-Variant"], @"Wrong local variant in event headers");
}

- (void) setCurrentLocale:(NSString*)localeCode {
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:localeCode];
    [locale autorelease];
    
    
    id mockLocaleClass = [OCMockObject mockForClass:[NSLocale class]];
    [[[mockLocaleClass stub] andReturn:locale] currentLocale];
}

- (void) setTimeZone:(NSString*)name {
    NSTimeZone *timeZone = [[NSTimeZone alloc] initWithName:name];
    [timeZone autorelease];
    
    
    id mockTimeZone = [OCMockObject mockForClass:[NSTimeZone class]];
    [[[mockTimeZone stub] andReturn:timeZone] systemTimeZone];
}

@end
