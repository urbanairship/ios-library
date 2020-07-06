/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UALocaleManager+Internal.h"
#import "UAPreferenceDataStore+Internal.h"

@interface UALocaleManagerTest : UAAirshipBaseTest
@property (nonatomic, strong) UALocaleManager *localeManager;
@property (nonatomic, strong) id mockNotificationCenter;
@end

@interface UALocaleManager()
- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore notificationCenter:(NSNotificationCenter *)notificationCenter;
@end

@implementation UALocaleManagerTest

- (void)setUp {
    self.mockNotificationCenter =  [self mockForClass:[NSNotificationCenter class]];
    self.localeManager = [[UALocaleManager alloc] initWithDataStore:self.dataStore notificationCenter:self.mockNotificationCenter];
}

- (void)testFirstInitLocale {
    XCTAssertEqual(self.localeManager.currentLocale.localeIdentifier, [NSLocale autoupdatingCurrentLocale].localeIdentifier);
    XCTAssertEqual(self.localeManager.currentLocale.countryCode, [NSLocale autoupdatingCurrentLocale].countryCode);
    XCTAssertEqual(self.localeManager.currentLocale.languageCode, [NSLocale autoupdatingCurrentLocale].languageCode);
    XCTAssertEqual(self.localeManager.currentLocale.scriptCode, [NSLocale autoupdatingCurrentLocale].scriptCode);
    XCTAssertEqual(self.localeManager.currentLocale.variantCode, [NSLocale autoupdatingCurrentLocale].variantCode);
    XCTAssertEqual(self.localeManager.currentLocale.currencyCode, [NSLocale autoupdatingCurrentLocale].currencyCode);
}

- (void)testSetLocale {
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:@"fr"];
    [[self.mockNotificationCenter expect] postNotificationName:UALocaleUpdatedEvent
            object:[NSDictionary dictionaryWithObject:locale forKey:UALocaleUpdatedEventLocaleKey]];
    
    self.localeManager.currentLocale = locale;
    XCTAssertEqual(self.localeManager.currentLocale, locale);
    [self.mockNotificationCenter verify];
}

- (void)testSetAndClearLocale {
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:@"fr"];
    self.localeManager.currentLocale = locale;
    
    [[self.mockNotificationCenter expect] postNotificationName:UALocaleUpdatedEvent
         object:[NSDictionary dictionaryWithObject:[NSLocale autoupdatingCurrentLocale] forKey:UALocaleUpdatedEventLocaleKey]];
    [self.localeManager clearLocale];
    
    XCTAssertEqual(self.localeManager.currentLocale.localeIdentifier, [NSLocale autoupdatingCurrentLocale].localeIdentifier);
    XCTAssertEqual(self.localeManager.currentLocale.countryCode, [NSLocale autoupdatingCurrentLocale].countryCode);
    XCTAssertEqual(self.localeManager.currentLocale.languageCode, [NSLocale autoupdatingCurrentLocale].languageCode);
    XCTAssertEqual(self.localeManager.currentLocale.scriptCode, [NSLocale autoupdatingCurrentLocale].scriptCode);
    XCTAssertEqual(self.localeManager.currentLocale.variantCode, [NSLocale autoupdatingCurrentLocale].variantCode);
    XCTAssertEqual(self.localeManager.currentLocale.currencyCode, [NSLocale autoupdatingCurrentLocale].currencyCode);
     [self.mockNotificationCenter verify];
}

- (void)testSetLocaleToNil {
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:@"fr"];
    self.localeManager.currentLocale = locale;
    
    [[self.mockNotificationCenter expect] postNotificationName:UALocaleUpdatedEvent
    object:[NSDictionary dictionaryWithObject:[NSLocale autoupdatingCurrentLocale] forKey:UALocaleUpdatedEventLocaleKey]];
    self.localeManager.currentLocale = nil;
    
    XCTAssertEqual(self.localeManager.currentLocale.localeIdentifier, [NSLocale autoupdatingCurrentLocale].localeIdentifier);
    XCTAssertEqual(self.localeManager.currentLocale.countryCode, [NSLocale autoupdatingCurrentLocale].countryCode);
    XCTAssertEqual(self.localeManager.currentLocale.languageCode, [NSLocale autoupdatingCurrentLocale].languageCode);
    XCTAssertEqual(self.localeManager.currentLocale.scriptCode, [NSLocale autoupdatingCurrentLocale].scriptCode);
    XCTAssertEqual(self.localeManager.currentLocale.variantCode, [NSLocale autoupdatingCurrentLocale].variantCode);
    XCTAssertEqual(self.localeManager.currentLocale.currencyCode, [NSLocale autoupdatingCurrentLocale].currencyCode);
    [self.mockNotificationCenter verify];
}
@end
