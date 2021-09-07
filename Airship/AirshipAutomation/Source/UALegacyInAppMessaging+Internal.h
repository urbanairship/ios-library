/* Copyright Airship and Contributors */

#import "UALegacyInAppMessaging.h"
#import "UAAirshipAutomationCoreImport.h"

// OLD storage keys

// User defaults key for storing and retrieving pending messages
#define kUAPendingInAppMessageDataStoreKey @"UAPendingInAppMessage"

// User defaults key for storing and retrieving auto display enabled
#define kUAAutoDisplayInAppMessageDataStoreKey @"UAAutoDisplayInAppMessageDataStoreKey"

// NEW storage keys

// Data store key for storing and retrieving pending message IDs
#define kUAPendingInAppMessageIDDataStoreKey @"UAPendingInAppMessageID"

@class UAPreferenceDataStore;
@protocol UAAnalyticsProtocol;
@class UAPush;
@class UNNotificationResponse;
@class UNNotificationContent;
@class UAInAppAutomation;

NS_ASSUME_NONNULL_BEGIN
/*
 * SDK-private extensions to UALegacyInAppMessaging
 */
@interface UALegacyInAppMessaging ()

///---------------------------------------------------------------------------------------
/// @name Legacy In App Messaging Internal Properties
///---------------------------------------------------------------------------------------

@property(nonatomic, copy, nullable) NSString *pendingMessageID;

///---------------------------------------------------------------------------------------
/// @name Legacy In App Messaging Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an UALegacyInAppMessaging instance.
 * @param analytics The UAAnalytics instance.
 * @param dataStore The preference data store.
 * @param inAppAutomation The in-app automation instance.
 * @return An instance of UALegacyInAppMessaging.
 */
+ (instancetype)inAppMessagingWithAnalytics:(id<UAAnalyticsProtocol>)analytics
                                  dataStore:(UAPreferenceDataStore *)dataStore
                            inAppAutomation:(UAInAppAutomation *)inAppAutomation;


@end

NS_ASSUME_NONNULL_END
