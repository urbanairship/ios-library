/* Copyright 2017 Urban Airship and Contributors */

#import "UALegacyInAppMessaging+Internal.h"
#import "UALegacyInAppMessage.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAAnalytics.h"
#import "UALegacyInAppResolutionEvent+Internal.h"
#import "UANotificationContent.h"
#import "UANotificationResponse.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessageManager.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UANotificationAction.h"
#import "UAColorUtils+Internal.h"
#import "UAGlobal.h"

#if !TARGET_OS_TV
#import "UAInboxUtils.h"
#import "UADisplayInboxAction.h"
#import "UAOverlayInboxMessageAction.h"
#endif

// Legacy key for the last displayed message ID
NSString *const UALastDisplayedInAppMessageID = @"UALastDisplayedInAppMessageID";

// The default primary color for IAMs: white
#define kUALegacyInAppMessageDefaultPrimaryColor [UIColor whiteColor]

// The default secondary color for IAMs: gray-ish
#define kUALegacyInAppMessageDefaultSecondaryColor [UIColor colorWithRed:(28.0/255.0) green:(28.0/255.0) blue:(28.0/255.0) alpha:1]

// APNS payload key
#define kUALegacyIncomingInAppMessageKey @"com.urbanairship.in_app"


@interface UALegacyInAppMessaging ()
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UAAnalytics *analytics;
@property(nonatomic, weak) UAInAppMessageManager *inAppMessageManager;
@end

@implementation UALegacyInAppMessaging

- (instancetype)initWithAnalytics:(UAAnalytics *)analytics
                        dataStore:(UAPreferenceDataStore *)dataStore
              inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager {

    self = [super init];
    if (self) {
        // Clean up the old datastore
        [self.dataStore removeObjectForKey:kUAPendingInAppMessageDataStoreKey];
        [self.dataStore removeObjectForKey:kUAAutoDisplayInAppMessageDataStoreKey];
        [self.dataStore removeObjectForKey:UALastDisplayedInAppMessageID];

        self.dataStore = dataStore;
        self.analytics = analytics;
        self.inAppMessageManager = inAppMessageManager;

        self.factoryDelegate = self;
    }

    return self;
}

+ (instancetype)inAppMessagingWithAnalytics:(UAAnalytics *)analytics
                                  dataStore:(UAPreferenceDataStore *)dataStore
                        inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager {

    return [[UALegacyInAppMessaging alloc] initWithAnalytics:analytics
                                                   dataStore:dataStore
                                         inAppMessageManager:inAppMessageManager];
}

- (NSString *)pendingMessageID {
    return [self.dataStore objectForKey:kUAPendingInAppMessageIDDataStoreKey];
}

- (void)setPendingMessageID:(NSString *)pendingMessageID {
    [self.dataStore setObject:pendingMessageID forKey:kUAPendingInAppMessageIDDataStoreKey];
}

- (void)handleNotificationResponse:(UANotificationResponse *)response {
    NSDictionary *apnsPayload = response.notificationContent.notificationInfo;
    if (!apnsPayload[kUALegacyIncomingInAppMessageKey]) {
        return;
    }

    NSString *newMessageID = apnsPayload[@"_"];
    NSString *pendingMessageID = self.pendingMessageID;

    if (newMessageID.length && [newMessageID isEqualToString:pendingMessageID]) {
        [self.inAppMessageManager getSchedulesWithMessageID:pendingMessageID completionHandler:^(NSArray<UASchedule *> *schedules) {
            if (schedules.count) {
                UA_LINFO(@"The in-app message delivery push was directly launched for message: %@", pendingMessageID);
                [self.inAppMessageManager cancelMessageWithID:pendingMessageID];
                self.pendingMessageID = nil;

                UALegacyInAppResolutionEvent *event = [UALegacyInAppResolutionEvent directOpenResolutionWithMessageID:pendingMessageID];
                [self.analytics addEvent:event];
            } else {
                self.pendingMessageID = nil;
            }
        }];
    }
}

- (void)handleRemoteNotification:(UANotificationContent *)notification {
    // Set the send ID as the IAM unique identifier
    NSDictionary *apnsPayload = notification.notificationInfo;

    if (!apnsPayload[kUALegacyIncomingInAppMessageKey]) {
        return;
    }

    NSMutableDictionary *messagePayload = [NSMutableDictionary dictionaryWithDictionary:apnsPayload[kUALegacyIncomingInAppMessageKey]];
    UALegacyInAppMessage *message = [UALegacyInAppMessage messageWithPayload:messagePayload];

    if (apnsPayload[@"_"]) {
        message.identifier = apnsPayload[@"_"];
    }

#if !TARGET_OS_TV   // Inbox not supported on tvOS
    NSString *inboxMessageID = [UAInboxUtils inboxMessageIDFromNotification:apnsPayload];
    if (inboxMessageID) {
        NSSet *inboxActionNames = [NSSet setWithArray:@[kUADisplayInboxActionDefaultRegistryAlias,
                                                        kUADisplayInboxActionDefaultRegistryName,
                                                        kUAOverlayInboxMessageActionDefaultRegistryAlias,
                                                        kUAOverlayInboxMessageActionDefaultRegistryName]];

        NSSet *actionNames = [NSSet setWithArray:message.onClick.allKeys];

        if (![actionNames intersectsSet:inboxActionNames]) {
            NSMutableDictionary *actions = [NSMutableDictionary dictionaryWithDictionary:message.onClick];
            actions[kUADisplayInboxActionDefaultRegistryAlias] = inboxMessageID;
            message.onClick = actions;
        }
    }
#endif

    [self scheduleMessage:message];
}

- (void)scheduleMessage:(UALegacyInAppMessage *)message {
    UAInAppMessageScheduleInfo *info =  [self.factoryDelegate scheduleInfoForMessage:message];
    if (!info) {
        UA_LERR(@"Failed to convert legacy in-app message: %@", message);
        return;
    }

    NSString *messageID = info.message.identifier;

    NSString *pendingMessageID = self.pendingMessageID;

    void (^scheduleBlock)(void) = ^{
        // Schedule the new one
        self.pendingMessageID = messageID;
        [self.inAppMessageManager scheduleMessageWithScheduleInfo:info completionHandler:^(UASchedule * schedule){
            UA_LDEBUG(@"LegacyInAppMessageManager - saved schedule: %@", schedule);
        }];
    };

    // If there is a pending message ID, check to see if it's still scheduled
    if (pendingMessageID) {
        [self.inAppMessageManager getSchedulesWithMessageID:pendingMessageID completionHandler:^(NSArray<UASchedule *> *schedules) {
            // If it's still scheduled, cancel it
            if (schedules.count) {
                [self.inAppMessageManager cancelMessageWithID:pendingMessageID];

                UA_LDEBUG(@"LegacyInAppMessageManager - Pending in-app message replaced");

                UALegacyInAppResolutionEvent *resolutionEvent = [UALegacyInAppResolutionEvent replacedResolutionWithMessageID:pendingMessageID replacement:messageID];
                [self.analytics addEvent:resolutionEvent];
            } else {
                self.pendingMessageID = nil;
            }

            scheduleBlock();
        }];
    } else {
        scheduleBlock();
    }
}

- (UAInAppMessageScheduleInfo *)scheduleInfoForMessage:(UALegacyInAppMessage *)message {
    UIColor *primaryColor = message.primaryColor ? message.primaryColor : kUALegacyInAppMessageDefaultPrimaryColor;
    UIColor *secondaryColor = message.secondaryColor ? message.secondaryColor : kUALegacyInAppMessageDefaultSecondaryColor;
    float borderRadius = 2;

    UAInAppMessageBannerDisplayContent *displayContent = [UAInAppMessageBannerDisplayContent bannerDisplayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder * _Nonnull builder) {
        builder.backgroundColor = primaryColor;
        builder.dismissButtonColor = secondaryColor;
        builder.borderRadius = borderRadius;
        builder.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        builder.placement = message.position == UALegacyInAppMessagePositionTop ? UAInAppMessageBannerPlacementTop : UAInAppMessageBannerPlacementBottom;
        builder.actions = message.onClick;

        UAInAppMessageTextInfo *textInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
            builder.text = message.alert;
            builder.color = secondaryColor;
        }];

        builder.body = textInfo;

        builder.duration = message.duration * 1000;

        NSMutableArray<UAInAppMessageButtonInfo *> *buttonInfos = [NSMutableArray array];

        for (int i = 0; i < message.notificationActions.count; i++) {
            if (i > UAInAppMessageBannerMaxButtons) {
                break;
            }
            UANotificationAction *notificationAction = [message.notificationActions objectAtIndex:i];
            UAInAppMessageTextInfo *labelInfo = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.alignment = NSTextAlignmentCenter;
                builder.color = primaryColor;
                builder.text = notificationAction.title;
            }];

            UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
                builder.actions = message.buttonActions[notificationAction.identifier];
                builder.identifier = notificationAction.identifier;
                builder.backgroundColor = secondaryColor;
                builder.borderRadius = borderRadius;
                builder.label = labelInfo;
            }];

            if (buttonInfo) {
                [buttonInfos addObject:buttonInfo];
            }
        }

        builder.buttons = buttonInfos;
    }];

    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo inAppMessageScheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder * _Nonnull builder) {
        builder.triggers = @[[UAScheduleTrigger activeSessionTriggerWithCount:1]];
        builder.end = message.expiry;

        UAInAppMessage *newMessage = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
            builder.displayContent = displayContent;
            builder.extras = message.extra;
            builder.identifier = message.identifier;
            // Todo: this should not have to be set manually
            builder.displayType = UAInAppMessageDisplayTypeBanner;
        }];

        builder.message = newMessage;
    }];

    return scheduleInfo;
}

@end
