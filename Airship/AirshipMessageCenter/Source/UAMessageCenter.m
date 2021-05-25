/* Copyright Airship and Contributors */

#import "UAMessageCenter+Internal.h"
#import "UADefaultMessageCenterUI.h"
#import "UAMessageCenterStyle.h"
#import "UAInboxMessageList+Internal.h"
#import "UAUser+Internal.h"
#import "UAInboxMessage.h"
#import "UAInboxUtils.h"

#import "UAAirshipMessageCenterCoreImport.h"


@interface UAMessageCenter()
@property (nonatomic, strong) UADefaultMessageCenterUI *defaultUI;
@property (nonatomic, strong) UAInboxMessageList *messageList;
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@end

@implementation UAMessageCenter

NSString *const UAMessageDataScheme = @"message";

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                             user:(UAUser *)user
                      messageList:(UAInboxMessageList *)messageList
                        defaultUI:(UADefaultMessageCenterUI *)defaultUI
               notificationCenter:(NSNotificationCenter *)notificationCenter
                   privacyManager:(UAPrivacyManager *)privacyManager {

    self = [super initWithDataStore:dataStore];
    if (self) {
        self.user = user;
        self.messageList = messageList;
        self.defaultUI = defaultUI;
        self.privacyManager = privacyManager;

        [self updateEnableState];

        [notificationCenter addObserver:self
                               selector:@selector(userCreated)
                                   name:UAUserCreatedNotification
                                 object:nil];

        [notificationCenter addObserver:self
                               selector:@selector(applicationDidTransitionToForeground)
                                   name:UAApplicationDidTransitionToForeground
                                 object:nil];
        
        // Update message center when enabled features change
        [notificationCenter addObserver:self
                               selector:@selector(onEnabledFeaturesChanged)
                                   name:UAPrivacyManagerEnabledFeaturesChangedEvent
                                 object:nil];

        [self.messageList loadSavedMessages];
    }

    return self;
}

+ (instancetype)messageCenterWithDataStore:(UAPreferenceDataStore *)dataStore
                                    config:(UARuntimeConfig *)config
                                   channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                            privacyManager:(UAPrivacyManager *)privacyManager {

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    UADefaultMessageCenterUI *defaultUI = [[UADefaultMessageCenterUI alloc] init];
    defaultUI.messageCenterStyle = [UAMessageCenterStyle styleWithContentsOfFile:config.messageCenterStyleConfig];

    UAUser *user = [UAUser userWithChannel:channel
                                    config:config
                                 dataStore:dataStore];
    
    UAInboxMessageList *messageList = [UAInboxMessageList messageListWithUser:user
                                                                       config:config
                                                                    dataStore:dataStore];

    return [[self alloc] initWithDataStore:dataStore
                                      user:user
                               messageList:messageList
                                 defaultUI:defaultUI
                        notificationCenter:notificationCenter
                            privacyManager:privacyManager];
}

+ (instancetype)messageCenterWithDataStore:(UAPreferenceDataStore *)dataStore
                                      user:(UAUser *)user
                               messageList:(UAInboxMessageList *)messageList
                                 defaultUI:(UADefaultMessageCenterUI *)defaultUI
                        notificationCenter:(NSNotificationCenter *)notificationCenter
                            privacyManager:(UAPrivacyManager *)privacyManager {

    return [[self alloc] initWithDataStore:dataStore
                                      user:user
                               messageList:messageList
                                 defaultUI:defaultUI
                        notificationCenter:notificationCenter
                            privacyManager:privacyManager];
}

- (void)display:(BOOL)animated {
    id<UAMessageCenterDisplayDelegate> displayDelegate = self.displayDelegate ?: self.defaultUI;
    [displayDelegate displayMessageCenterAnimated:animated];
}

- (void)display {
    if ([self.privacyManager isEnabled:UAFeaturesMessageCenter]) {
        [self display:YES];
    } else {
        UA_LWARN(@"Message center disabled. Unable to display.");
    }
}

- (void)displayMessageForID:(NSString *)messageID animated:(BOOL)animated {
    id<UAMessageCenterDisplayDelegate> displayDelegate = self.displayDelegate ?: self.defaultUI;
    [displayDelegate displayMessageCenterForMessageID:messageID animated:animated];
}

- (void)displayMessageForID:(NSString *)messageID {
    if (self.componentEnabled && [self.privacyManager isEnabled:UAFeaturesMessageCenter]) {
        [self displayMessageForID:messageID animated:YES];
    } else {
        UA_LWARN(@"Message center disabled. Unable to display the message.");
    }
}

- (void)dismiss:(BOOL)animated {
    id<UAMessageCenterDisplayDelegate> displayDelegate = self.displayDelegate ?: self.defaultUI;
    [displayDelegate dismissMessageCenterAnimated:animated];
}

- (void)dismiss {
    [self dismiss:YES];
}

- (void)applicationDidTransitionToForeground {
    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:nil];
}

- (void)userCreated {
    [self.messageList retrieveMessageListWithSuccessBlock:nil withFailureBlock:nil];
}

- (void)onComponentEnableChange {
    [self updateEnableState];
}

- (void)updateEnableState {
    BOOL isEnabled = self.componentEnabled && [self.privacyManager isEnabled:UAFeaturesMessageCenter];
    self.user.enabled = isEnabled;
    self.messageList.enabled = isEnabled;
}
#pragma mark -
#pragma mark UAPushableComponent

-(void)receivedRemoteNotification:(UANotificationContent *)notification
                completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSString *messageID = [UAInboxUtils inboxMessageIDFromNotification:notification.notificationInfo];
    if (!messageID) {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }

    [self.messageList retrieveMessageListWithSuccessBlock:^{
        UAInboxMessage *message = [self.messageList messageForID:messageID];
        if (!message) {
            completionHandler(UIBackgroundFetchResultNoData);
        } else {
            completionHandler(UIBackgroundFetchResultNewData);
        }
    } withFailureBlock:^{
        completionHandler(UIBackgroundFetchResultFailed);
    }];
}

#pragma mark -
#pragma mark UAPrivacyManager

- (void)onEnabledFeaturesChanged {
    [self updateEnableState];
}

@end
