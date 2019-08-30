/* Copyright Airship and Contributors */

#import "UAInbox.h"
#import "UAAppStateTrackerFactory.h"

@class UAUser;
@class UARuntimeConfig;
@class UAPreferenceDataStore;

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAInbox
 */
@interface UAInbox () <UAAppStateTrackerDelegate>

///---------------------------------------------------------------------------------------
/// @name Inbox Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The inbox API client.
 */
@property (nonatomic, strong) UAInboxAPIClient *client;

/**
 * The inbox user.
 */
@property (nonatomic, strong) UAUser *user;

/**
 *The app state tracker.
 */
@property (nonatomic, strong) id<UAAppStateTracker> appStateTracker;

/**
 * Whether the application has already become active for the first time.
 */
@property (nonatomic, assign) BOOL becameActive;

///---------------------------------------------------------------------------------------
/// @name Inbox Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create an inbox.
 * @param user The inbox user.
 * @param config The Airship config.
 * @param dataStore The preference data store.
 * @return The user's inbox.
 */
+ (instancetype)inboxWithUser:(UAUser *)user
                       config:(UARuntimeConfig *)config
                    dataStore:(UAPreferenceDataStore *)dataStore;

@end

NS_ASSUME_NONNULL_END
