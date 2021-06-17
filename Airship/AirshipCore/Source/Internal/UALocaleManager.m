/* Copyright Airship and Contributors */

#import "UALocaleManager+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

NSString *const UALocaleUpdatedEventLocaleKey = @"com.urbanairship.locale.locale";
NSString *const UALocaleUpdatedEvent = @"com.urbanairship.locale.locale_updated";

@interface UALocaleManager()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UALocaleManager

+ (instancetype)localeManagerWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[UALocaleManager alloc] initWithDataStore:dataStore notificationCenter:[NSNotificationCenter defaultCenter]];
}

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];
    if (self) {
        self.dataStore = dataStore;
        self.notificationCenter = notificationCenter;
    }
    return self;
}

- (void)setCurrentLocale:(NSLocale *)currentLocale {
    if ([self.currentLocale isEqual:currentLocale]) {
        return;
    }

    if (!currentLocale) {
        [self clearLocale];
        return;
    }
    NSData *encodedLocale = [NSKeyedArchiver archivedDataWithRootObject:currentLocale];
    [self.dataStore setObject:encodedLocale forKey:UALocaleUpdatedEventLocaleKey];

    NSDictionary *localeDictionary = [NSDictionary dictionaryWithObject:currentLocale forKey:UALocaleUpdatedEventLocaleKey];
    [self.notificationCenter postNotificationName:UALocaleUpdatedEvent object:localeDictionary];
}

- (NSLocale *)currentLocale {
    NSData *encodedLocale = [self.dataStore objectForKey:UALocaleUpdatedEventLocaleKey];
    if (encodedLocale) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:encodedLocale];
    } else {
        return [NSLocale autoupdatingCurrentLocale];
    }
}

- (void)clearLocale {
    [self.dataStore removeObjectForKey:UALocaleUpdatedEventLocaleKey];

    NSLocale *defaultLocale = [NSLocale autoupdatingCurrentLocale];
    NSDictionary *localeDictionary = [NSDictionary dictionaryWithObject:defaultLocale forKey:UALocaleUpdatedEventLocaleKey];
    [self.notificationCenter postNotificationName:UALocaleUpdatedEvent object:localeDictionary];
}


@end
