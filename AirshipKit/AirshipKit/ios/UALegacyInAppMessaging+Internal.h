/* Copyright Airship and Contributors */

#import "UALegacyInAppMessaging.h"
#import "UAPushableComponent.h"

// OLD storage keys

// User defaults key for storing and retrieving pending messages
#define kUAPendingInAppMessageDataStoreKey @"UAPendingInAppMessage"

// User defaults key for storing and retrieving auto display enabled
#define kUAAutoDisplayInAppMessageDataStoreKey @"UAAutoDisplayInAppMessageDataStoreKey"

// NEW storage keys

// Data store key for storing and retrieving pending message IDs
#define kUAPendingInAppMessageIDDataStoreKey @"UAPendingInAppMessageID"

@class UAPreferenceDataStore;
@class UAAnalytics;
@class UAPush;
@class UANotificationResponse;
@class UANotificationContent;
@class UAInAppMessageManager;

NS_ASSUME_NONNULL_BEGIN
/*
 * SDK-private extensions to UALegacyInAppMessaging
 */
@interface UALegacyInAppMessaging () <UAPushableComponent>

///---------------------------------------------------------------------------------------
/// @name In App Messaging Internal Properties
///---------------------------------------------------------------------------------------

@property(nonatomic, copy, nullable) NSString *pendingMessageID;

///---------------------------------------------------------------------------------------
/// @name In App Messaging Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an UALegacyInAppMessaging instance.
 * @param analytics The UAAnalytics instance.
 * @param dataStore The preference data store.
 * @return An instance of UALegacyInAppMessaging.
 */
+ (instancetype)inAppMessagingWithAnalytics:(UAAnalytics *)analytics
                                  dataStore:(UAPreferenceDataStore *)dataStore
                        inAppMessageManager:(UAInAppMessageManager *)inAppMessageManager;


@end

NS_ASSUME_NONNULL_END
