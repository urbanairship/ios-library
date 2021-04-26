/* Copyright Airship and Contributors */

#import "UAAccengage+Internal.h"
#import "UAActionRunner.h"
#import "UAAccengagePayload.h"
#import "UAChannelRegistrationPayload.h"
#import "UAExtendableChannelRegistration.h"
#import "UAJSONSerialization.h"
#import "UAAccengageUtils.h"
#import "UAAccengageResources.h"
#import "UANotificationCategories.h"
#import "UAPush.h"
#import "ACCStubData+Internal.h"

static NSString * const UAAccengageIDKey = @"a4sid";
static NSString * const UAAccengageForegroundKey = @"a4sd";
NSString *const UAAccengageSettingsMigrated = @"UAAccengageSettingsMigrated";

@interface UAAccengage() <NSKeyedUnarchiverDelegate>
@property (nonatomic, strong) NSDictionary *accengageSettings;
@end

@implementation UAAccengage

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                             push:(UAPush *)push
                        analytics:(UAAnalytics *)analytics {
    self = [super initWithDataStore:dataStore];
    if (self) {
        UA_WEAKIFY(self);
        [channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
            UA_STRONGIFY(self);
            [self extendChannelRegistrationPayload:payload completionHandler:completionHandler];
        }];

        NSSet *accengageCategories = [UANotificationCategories createCategoriesFromFile:[[UAAccengageResources bundle] pathForResource:@"UAAccengageNotificationCategories" ofType:@"plist"]];
        push.accengageCategories = accengageCategories;
        
        BOOL settingsMigrated = [dataStore boolForKey:UAAccengageSettingsMigrated];
        if (!settingsMigrated) {
            [self migrateSettingsToAnalytics:analytics];
            [self migratePushSettings:push completionHandler:^{
                // Save the migration status
                [dataStore setBool:YES forKey:UAAccengageSettingsMigrated];
            }];
        }
    }
    return self;
}

+ (instancetype)accengageWithDataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                                  push:(UAPush *)push
                             analytics:(UAAnalytics *)analytics {

    return [[self alloc] initWithDataStore:dataStore channel:channel push:push analytics:analytics];
}

- (NSDictionary *)accengageSettings {
    if (!_accengageSettings) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths firstObject];

        _accengageSettings = @{};

        if (!documentsDirectory) {
            return _accengageSettings;
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
                    _accengageSettings = data;
                }
            }
        }
    }
    
    return _accengageSettings;
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

- (void)receivedNotificationResponse:(UANotificationResponse *)response
                   completionHandler:(void (^)(void))completionHandler {
    // check for accengage push response, handle actions
    NSDictionary *notificationInfo = response.notificationContent.notificationInfo;

    UAAccengagePayload *payload = [UAAccengagePayload payloadWithDictionary:notificationInfo];

    if (!payload.identifier) {
        // not an Accengage push
        completionHandler();
        return;
    }

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

    if (![response.actionIdentifier isEqualToString:UANotificationDismissActionIdentifier] && ![response.actionIdentifier isEqualToString:UANotificationDefaultActionIdentifier] &&
        payload.buttons) {
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

- (void)migrateSettingsToAnalytics:(UAAnalytics *)analytics {
    NSDictionary *dataDictionary = self.accengageSettings;
    id accAnalytics = dataDictionary[@"DoNotTrack"];
    if ([accAnalytics isKindOfClass:[NSNumber class]]) {
        NSNumber *analyticsDisabled = accAnalytics;
        analytics.enabled = ![analyticsDisabled boolValue];
    }
}

- (void)migratePushSettings:(UAPush *)push completionHandler:(void (^)(void))completionHandler {
    // get system push opt-in setting
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull notificationSettings) {
        UNAuthorizationStatus status = notificationSettings.authorizationStatus;
        if (status == UNAuthorizationStatusAuthorized) {
            push.userPushNotificationsEnabled = YES;
            completionHandler();
        } else {
            if (@available(iOS 12.0, *)) {
                if (status == UNAuthorizationStatusProvisional) {
                    push.userPushNotificationsEnabled = YES;
                    completionHandler();
                    return;
                }
            }
            push.userPushNotificationsEnabled = NO;
            completionHandler();
        }
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

#pragma mark -
#pragma mark Channel Registration Events

- (void)extendChannelRegistrationPayload:(UAChannelRegistrationPayload *)payload
                       completionHandler:(UAChannelRegistrationExtenderCompletionHandler)completionHandler {

    // get the Accengage ID and set it as an identity hint
    NSDictionary *dataDictionary = self.accengageSettings;
    id accengageDeviceID = dataDictionary[@"BMA4SID"];

    if ([accengageDeviceID isKindOfClass:[NSString class]]) {
        if ([self isValidDeviceID:accengageDeviceID]) {
            payload.accengageDeviceID = accengageDeviceID;
        }
    }

    completionHandler(payload);
}

- (BOOL)isValidDeviceID:(NSString *)deviceID {
    return deviceID && deviceID.length && ![deviceID isEqualToString:@"00000000-0000-0000-0000-000000000000"];
}

- (nullable Class)unarchiver:(NSKeyedUnarchiver *)unarchiver cannotDecodeObjectOfClassName:(NSString *)name originalClasses:(NSArray<NSString *> *)classNames {
    return [ACCStubData class];
}

@end
