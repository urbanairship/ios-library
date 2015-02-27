
#import "UAInbox.h"

@class UAUser;
@class UAConfig;
@class UAPreferenceDataStore;

@interface UAInbox ()

/**
 * The inbox api client.
 */
@property (nonatomic, strong) UAInboxAPIClient *client;

/**
 * The inbox user.
 */
@property (nonatomic, strong) UAUser *user;

/**
 * Factory method to create an inbox.
 * @param user The inbox user.
 * @param config The Urban Airship config.
 * @param dataStore The preference data store.
 * @return The user's inbox.
 */
+ (instancetype)inboxWithUser:(UAUser *)user config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

@end
