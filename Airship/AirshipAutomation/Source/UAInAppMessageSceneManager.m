/* Copyright Airship and Contributors */

#import "UAInAppMessageSceneManager+Internal.h"

@interface UAInAppMessageSceneManager()
@property(nonatomic, strong) NSMutableArray<UIScene *> *scenes API_AVAILABLE(ios(13.0));
@property(nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation UAInAppMessageSceneManager
static UAInAppMessageSceneManager *shared_;

+ (void)load {
    shared_ = [UAInAppMessageSceneManager managerWithNotificationCenter:[NSNotificationCenter defaultCenter]];
}

+ (instancetype)shared {
    return shared_;
}

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];

    if (self) {
        self.notificationCenter = notificationCenter;
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            self.scenes = [NSMutableArray array];
            [self observeSceneEvents];
        }
    }
    return self;
}

+ (instancetype)managerWithNotificationCenter:(NSNotificationCenter *)notificationCenter {
    return [[self alloc] initWithNotificationCenter:notificationCenter];
}

- (void)observeSceneEvents API_AVAILABLE(ios(13.0)) {
    [self.notificationCenter addObserver:self
                                selector:@selector(sceneAdded:) name:UISceneWillConnectNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(sceneRemoved:)
                                    name:UISceneDidDisconnectNotification
                                  object:nil];
}

- (void)sceneAdded:(NSNotification *)notification API_AVAILABLE(ios(13.0)) {
    [self.scenes addObject:notification.object];
}

- (void)sceneRemoved:(NSNotification *)notification API_AVAILABLE(ios(13.0))  {
    [self.scenes removeObject:notification.object];
}

- (nullable UIWindowScene *)sceneForMessage:(UAInAppMessage *)message {
    UIWindowScene *messageScene = nil;
    UIWindowScene *activeMessageScene = nil;

    for (UIScene *scene in self.scenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        messageScene = (UIWindowScene *)scene;
        if (messageScene.activationState == UISceneActivationStateForegroundActive && [messageScene.session.role isEqualToString: UIWindowSceneSessionRoleApplication]) {
            activeMessageScene = messageScene;
        }
    }

    // Prefer the last active message scene
    messageScene = activeMessageScene ?: messageScene;

    // Give the delegate a chance to override
    id<UAInAppMessageSceneDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(sceneForMessage:defaultScene:)]) {
        messageScene = [delegate sceneForMessage:message defaultScene:messageScene] ?: messageScene;
    }

    return messageScene;
}

@end

