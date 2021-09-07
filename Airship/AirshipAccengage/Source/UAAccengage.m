/* Copyright Airship and Contributors */

#import "UAAccengage+Internal.h"
#import "UAAccengagePayload.h"
#import "UAAccengageUtils.h"
#import "UAAccengageResources.h"
#import "UAPush.h"
#import "ACCStubData+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

static NSString * const UAAccengageIDKey = @"a4sid";
static NSString * const UAAccengageForegroundKey = @"a4sd";
NSString *const UAAccengageSettingsMigrated = @"UAAccengageSettingsMigrated";

@interface UAAccengageSettingsLoader : NSObject<NSKeyedUnarchiverDelegate>

@end

@implementation UAAccengageSettingsLoader

- (NSDictionary *)loadAccengageSettings {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    if (!documentsDirectory) {
        return @{};
    }

    NSString *finalPath = [documentsDirectory stringByAppendingPathComponent:@"BMA4SUserDefault"];
    NSData *encodedData = [NSKeyedUnarchiver unarchiveObjectWithFile:finalPath];

    if (encodedData) {
        // use Accengage decryption key
        NSData *concreteData = [UAAccengageUtils decryptData:encodedData key:@"osanuthasoeuh"];
        if (concreteData) {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:concreteData error:nil];
            unarchiver.requiresSecureCoding = NO;
            unarchiver.delegate = self;
            id data = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
            if ([data isKindOfClass:[NSDictionary class]]) {
                return data;
            }
        }
    }

    return  @{};
}

- (nullable Class)unarchiver:(NSKeyedUnarchiver *)unarchiver cannotDecodeObjectOfClassName:(NSString *)name originalClasses:(NSArray<NSString *> *)classNames {
    return [ACCStubData class];
}

@end

@interface UAAccengage() <NSKeyedUnarchiverDelegate, UAPushableComponent>
@property (nonatomic, strong) UAComponentDisableHelper *disableHelper;
@end

@implementation UAAccengage

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                             push:(UAPush *)push
                   privacyManager:(UAPrivacyManager *)privacyManager
                accengageSettings:(NSDictionary *)settings {
    self = [super init];
    if (self) {
        self.disableHelper = [[UAComponentDisableHelper alloc] initWithDataStore:dataStore className:@"UAAccengage"];
        NSString *accengageDeviceID = [self parseAccengageDeviceIDFromSettings:settings];
        if (accengageDeviceID) {
            NSSet *accengageCategories = [UANotificationCategories createCategoriesFromFile:[[UAAccengageResources bundle] pathForResource:@"UAAccengageNotificationCategories" ofType:@"plist"]];
            push.accengageCategories = accengageCategories;
            [push updateRegistration];
            
            [channel addRegistrationExtender:^(UAChannelRegistrationPayload * payload, void (^ completionHandler)(UAChannelRegistrationPayload * _Nonnull)) {
                payload.identityHints = payload.identityHints ?: [[UAIdentityHints alloc] init];
                payload.identityHints.accengageDeviceID = accengageDeviceID;
                completionHandler(payload);
            }];

            [self migrateSettings:settings
                             push:push
                        dataStore:dataStore
                   privacyManager:privacyManager];
        }
    }

    return self;
}

+ (instancetype)accengageWithDataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel
                                  push:(UAPush *)push
                        privacyManager:(UAPrivacyManager *)privacyManager
                              settings:(NSDictionary *)settings {
    return [[self alloc] initWithDataStore:dataStore
                                   channel:channel
                                      push:push
                            privacyManager:privacyManager
                         accengageSettings:settings];
}

+ (instancetype)accengageWithDataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel
                                  push:(UAPush *)push
                        privacyManager:(UAPrivacyManager *)privacyManager {
    NSDictionary *settings = [[[UAAccengageSettingsLoader alloc] init] loadAccengageSettings];
    return [[self alloc] initWithDataStore:dataStore
                                   channel:channel
                                      push:push
                            privacyManager:privacyManager
                         accengageSettings:settings];
}

- (NSString *)parseAccengageDeviceIDFromSettings:(NSDictionary *)settings {
    // get the Accengage ID and set it as an identity hint
    id accengageDeviceID = settings[@"BMA4SID"];

    if ([accengageDeviceID isKindOfClass:[NSString class]]) {
        if ([self isValidDeviceID:accengageDeviceID]) {
            return accengageDeviceID;
        }
    }
    return nil;
}


- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification defaultPresentationOptions:(UNNotificationPresentationOptions)options {
    if (![self isAccengageNotification:notification]) {
        // Not an accengage push
        return options;
    }

    if ([self isForegroundNotification:notification]) {
        return (UANotificationOptionAlert | UANotificationOptionBadge | UANotificationOptionSound);
    } else {
        return UNNotificationPresentationOptionNone;
    }
}

- (void)receivedNotificationResponse:(UNNotificationResponse *)response
                   completionHandler:(void (^)(void))completionHandler {
    // check for accengage push response, handle actions
    NSDictionary *notificationInfo = response.notification.request.content.userInfo;

    UAAccengagePayload *payload = [UAAccengagePayload payloadWithDictionary:notificationInfo];

    if (!payload.identifier) {
        // not an Accengage push
        completionHandler();
        return;
    }

   
    
    if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        if (payload.url) {
            if (payload.hasExternalURLAction) {
                [UAActionRunner runActionWithName:@"open_external_url_action"
                                            value:payload.url
                                        situation:UASituationLaunchedFromPush];
            } else {
                [UAActionRunner runActionWithName:@"landing_page_action"
                                            value:payload.url
                                        situation:UASituationLaunchedFromPush];
            }
        }
    } else if (![response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier] && payload.buttons) {
        for (UAAccengageButton *button in payload.buttons) {
            if ([button.identifier isEqualToString:response.actionIdentifier]) {
                if ([button.actionType isEqualToString:UAAccengageButtonBrowserAction]) {
                    [UAActionRunner runActionWithName:@"open_external_url_action"
                                                value:button.url
                                            situation:UASituationForegroundInteractiveButton];
                } else if ([button.actionType isEqualToString:UAAccengageButtonWebviewAction]) {
                    [UAActionRunner runActionWithName:@"landing_page_action"
                                                value:button.url
                                            situation:UASituationForegroundInteractiveButton];
                }
            }
        }
    }
    
    completionHandler();
}

- (void)migrateSettings:(NSDictionary *)accengageSettings
                   push:(UAPush *)push
              dataStore:(UAPreferenceDataStore *)dataStore
         privacyManager:(UAPrivacyManager *)privacyManager {

    if ([dataStore boolForKey:UAAccengageSettingsMigrated]) {
        return;
    }

    // Analytics
    id accAnalytics = accengageSettings[@"DoNotTrack"];
    if ([accAnalytics isKindOfClass:[NSNumber class]]) {
        NSNumber *analyticsDisabled = accAnalytics;
        if (![analyticsDisabled boolValue]) {
            [privacyManager enableFeatures:UAFeaturesAnalytics];
        } else {
            [privacyManager disableFeatures:UAFeaturesAnalytics];
        }
    }

    // get system push opt-in setting
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull notificationSettings) {
        UNAuthorizationStatus status = notificationSettings.authorizationStatus;

        BOOL enablePush = NO;
        if (status == UNAuthorizationStatusAuthorized) {
            enablePush = YES;
        } else if (@available(iOS 12.0, *)) {
            if (status == UNAuthorizationStatusProvisional) {
                enablePush = YES;
                return;
            }
        }

        if (enablePush) {
            push.userPushNotificationsEnabled = enablePush;
            [privacyManager enableFeatures:UAFeaturesPush];
        }

        [dataStore setBool:YES forKey:UAAccengageSettingsMigrated];
    }];
}

- (BOOL)isAccengageNotification:(UNNotification *)notification {
    id accengageNotificationID = notification.request.content.userInfo[UAAccengageIDKey];
    return [accengageNotificationID isKindOfClass:[NSString class]];
}

- (BOOL)isForegroundNotification:(UNNotification *)notification {
    id isForegroundNotification = notification.request.content.userInfo[UAAccengageForegroundKey];
    if ([isForegroundNotification isKindOfClass:[NSString class]]) {
        return [isForegroundNotification boolValue];
    } else {
        return NO;
    }
}

- (BOOL)isValidDeviceID:(NSString *)deviceID {
    return deviceID && deviceID.length && ![deviceID isEqualToString:@"00000000-0000-0000-0000-000000000000"];
}

- (BOOL)isComponentEnabled {
    return self.disableHelper.enabled;
}

- (void)setComponentEnabled:(BOOL)componentEnabled {
    self.disableHelper.enabled = componentEnabled;
}

@end

