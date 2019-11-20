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
@end

@implementation UAMessageCenter

NSString *const UAMessageDataScheme = @"message";

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                             user:(UAUser *)user
                      messageList:(UAInboxMessageList *)messageList
                        defaultUI:(UADefaultMessageCenterUI *)defaultUI
               notificationCenter:(NSNotificationCenter *)notificationCenter {

    self = [super initWithDataStore:dataStore];
    if (self) {
        self.user = user;
        self.messageList = messageList;
        self.defaultUI = defaultUI;

        self.user.enabled = self.componentEnabled;
        self.messageList.enabled = self.componentEnabled;

        [notificationCenter addObserver:self
                               selector:@selector(userCreated)
                                   name:UAUserCreatedNotification
                                 object:nil];

        [notificationCenter addObserver:self
                               selector:@selector(applicationDidTransitionToForeground)
                                   name:UAApplicationDidTransitionToForeground
                                 object:nil];

        [self.messageList loadSavedMessages];
    }

    return self;
}

+ (instancetype)messageCenterWithDataStore:(UAPreferenceDataStore *)dataStore
                                    config:(UARuntimeConfig *)config
                                   channel:(UAChannel<UAExtendableChannelRegistration> *)channel {

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    UADefaultMessageCenterUI *defaultUI = [[UADefaultMessageCenterUI alloc] init];
    defaultUI.style = [UAMessageCenterStyle styleWithContentsOfFile:config.messageCenterStyleConfig];

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
                        notificationCenter:notificationCenter];
}

+ (instancetype)messageCenterWithDataStore:(UAPreferenceDataStore *)dataStore
                                      user:(UAUser *)user
                               messageList:(UAInboxMessageList *)messageList
                                 defaultUI:(UADefaultMessageCenterUI *)defaultUI
                        notificationCenter:(NSNotificationCenter *)notificationCenter {

    return [[self alloc] initWithDataStore:dataStore
                                      user:user
                               messageList:messageList
                                 defaultUI:defaultUI
                        notificationCenter:notificationCenter];
}

- (void)display:(BOOL)animated {
    id<UAMessageCenterDisplayDelegate> displayDelegate = self.displayDelegate ?: self.defaultUI;
    [displayDelegate displayMessageCenterAnimated:animated];
}

- (void)display {
    [self display:YES];
}

- (void)displayMessageForID:(NSString *)messageID animated:(BOOL)animated {
    id<UAMessageCenterDisplayDelegate> displayDelegate = self.displayDelegate ?: self.defaultUI;
    [displayDelegate displayMessageCenterForMessageID:messageID animated:animated];
}

- (void)displayMessageForID:(NSString *)messageID {
    [self displayMessageForID:messageID animated:YES];
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
    self.user.enabled = self.componentEnabled;
    self.messageList.enabled = self.componentEnabled;
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

@end
