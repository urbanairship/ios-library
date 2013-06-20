//
//  UAAnalyticsTest.m
//  AirshipLib
//
//

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
    STAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Varient"],  @"POSIX", @"Wrong local varient in event headers");
}

- (void)testAnalyticRequestLocationHeadersPartialCode {
    [self setCurrentLocale:@"de"];
    
    NSDictionary *headers = [self.analytics analyticsRequest].headers;
    
    STAssertEqualObjects([headers objectForKey:@"X-UA-Locale-Language"], @"de", @"Wrong local language code in event headers");
    STAssertNil([headers objectForKey:@"X-UA-Locale-Country"], @"Wrong local country code in event headers");
    STAssertNil([headers objectForKey:@"X-UA-Locale-Varient"], @"Wrong local varient in event headers");
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
