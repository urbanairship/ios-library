/* Copyright Airship and Contributors */

#import "UAInbox+Internal.h"
#import "UAirship.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAComponent+Internal.h"
#import "UAAppStateTrackerFactory+Internal.h"
#import "UAInboxUtils.h"

@implementation UAInbox

- (void)dealloc {
    [self.client.session cancelAllRequests];
}

- (instancetype)initWithUser:(UAUser *)user
                      config:(UARuntimeConfig *)config
                   dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super initWithDataStore:dataStore];
    if (self) {
        self.user = user;
        self.client = [UAInboxAPIClient clientWithConfig:config session:[UARequestSession sessionWithConfig:config] user:user dataStore:dataStore];
        self.client.enabled = self.componentEnabled;
        self.messageList = [UAInboxMessageList messageListWithUser:self.user client:self.client config:config];
        self.appStateTracker = [UAAppStateTrackerFactory tracker];
        self.appStateTracker.stateTrackerDelegate = self;


        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userCreated)
                                                     name:UAUserCreatedNotification
                                                   object:nil];

        [self.messageList loadSavedMessages];

        // delete legacy UAInboxCache if present
        [self deleteInboxCache];
    }
    
    return self;
}

+ (instancetype)inboxWithUser:(UAUser *)user
                       config:(UARuntimeConfig *)config
                    dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAInbox alloc] initWithUser:user config:config dataStore:dataStore];
}

- (void)didEnterForeground {
    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:nil];
}

- (void)applicationDidBecomeActive {
    // We only want to refresh the inbox on the first active. enterForeground will
    // handle any background->foreground inbox refresh
    if (!self.becameActive) {
        [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:nil];
        self.becameActive = YES;
    }
}

- (void)userCreated {
    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:nil];
}

- (void)onComponentEnableChange {
    // Disable/enable the API client and user to disable/enable the inbox
    self.user.componentEnabled = self.componentEnabled;
    self.client.enabled = self.componentEnabled;
}

//note: this is for deleting the UAInboxCache from disk, which is no longer in use.
- (void)deleteInboxCache{
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    NSString *diskCachePath = [NSString stringWithFormat:@"%@/%@", cacheDirectory, @"UAInboxCache"];

    NSFileManager *fm = [NSFileManager defaultManager];

    if ([fm fileExistsAtPath:diskCachePath]) {
        NSError *error = nil;
        [fm removeItemAtPath:diskCachePath error:&error];
        if (error) {
            UA_LTRACE(@"Error deleting inbox cache: %@", error.description);
        }
    }
}

#pragma mark -
#pragma mark UAPushableComponent
-(void)receivedRemoteNotification:(UANotificationContent *)notification completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSString *messageID = [UAInboxUtils inboxMessageIDFromNotification:notification.notificationInfo];
    BOOL isForegroundPush = self.appStateTracker.state == UAApplicationStateActive;

    if (!messageID) {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }

    [self.messageList retrieveMessageListWithSuccessBlock:^{
        if (isForegroundPush) {
            UAInboxMessage *message = [self.messageList messageForID:messageID];
            if (!message) {
                [[UADispatcher mainDispatcher] dispatchAsync:^{
                    id strongDelegate = self.delegate;
                    if ([strongDelegate respondsToSelector:@selector(richPushMessageAvailable:)]) {
                        [strongDelegate richPushMessageAvailable:message];
                    }
                    completionHandler(UIBackgroundFetchResultNewData);
                }];
            } else {
                completionHandler(UIBackgroundFetchResultNewData);
            }
        }
    } withFailureBlock:^{
        completionHandler(UIBackgroundFetchResultFailed);
    }];
}

#pragma mark -

@end
