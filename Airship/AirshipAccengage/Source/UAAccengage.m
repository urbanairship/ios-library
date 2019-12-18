/* Copyright Airship and Contributors */

#import "UAAccengage+Internal.h"
#import "UAActionRunner.h"
#import "UAAccengagePayload.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAExtendableChannelRegistration.h"
#import "UAJSONSerialization.h"
#import "UAAccengageUtils.h"
#import "UAAccengageResources.h"
#import "UANotificationCategories.h"
#import "UAPush+Internal.h"

static NSString * const UAAccengageIDKey = @"a4sid";
static NSString * const UAAccengageForegroundKey = @"a4sd";

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
        [self migrateSettingsToAnalytics:analytics];
        NSSet *accengageCategories = [UANotificationCategories createCategoriesFromFile:[[UAAccengageResources bundle] pathForResource:@"UAAccengageNotificationCategories" ofType:@"plist"]];
        push.accengageCategories = accengageCategories;
    }
    return self;
}

+ (instancetype)accengageWithDataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                                  push:(UAPush *)push
                             analytics:(UAAnalytics *)analytics {

    return [[self alloc] initWithDataStore:dataStore channel:channel push:push analytics:analytics];
}

- (UNNotificationPresentationOptions)presentationOptionsForNotification:(UNNotification *)notification defaultPresentationOptions:(UNNotificationPresentationOptions)options {
    if (![self isAccengageNotification:notification]) {
        // Not an accengage push
        return options;
    }
    
    if ([self isForegroundNotification:notification]) {
        return [UAPush shared].defaultPresentationOptions;
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
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    
    if (!documentsDirectory) {
        return;
    }
         
    NSString *finalPath = [documentsDirectory stringByAppendingPathComponent:@"BMA4SUserDefault"];
     
    NSData *encodedData = [NSKeyedUnarchiver unarchiveObjectWithFile:finalPath];

    if (encodedData) {
        // use Accengage decryption key
        NSData *concreteData = [UAAccengageUtils decryptData:encodedData key:@"osanuthasoeuh"];
        if (concreteData) {
            id data = [NSKeyedUnarchiver unarchiveObjectWithData:concreteData];
            if ([data isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dataDictionary = data;
                id accAnalytics = dataDictionary[@"DoNotTrack"];
                if ([accAnalytics isKindOfClass:[NSNumber class]]) {
                    NSNumber *analyticsDisabled = accAnalytics;
                    analytics.enabled = ![analyticsDisabled boolValue];
                }
            }
        }
    }
}

- (BOOL)isAccengageNotification:(UNNotification *)notification {
    id accengageNotificationID = notification.request.content.userInfo[UAAccengageIDKey];
    return [accengageNotificationID isKindOfClass:[NSString class]];
}

- (BOOL)isForegroundNotification:(UNNotification *)notification {
    id isForegroundNotification = notification.request.content.userInfo[UAAccengageForegroundKey];
    if ([isForegroundNotification isKindOfClass:[NSNumber class]]) {
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
    NSString *accengageDeviceID = UIDevice.currentDevice.identifierForVendor.UUIDString;
    
    payload.accengageDeviceID = accengageDeviceID;
    
    completionHandler(payload);
}

@end
