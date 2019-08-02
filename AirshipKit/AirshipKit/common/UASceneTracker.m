
#import "UASceneTracker+Internal.h"

@interface UASceneTracker ()

@property(nonatomic, strong) NSMutableArray<UIScene *> *scenes API_AVAILABLE(ios(13.0));
@property(nonatomic, strong) NSNotificationCenter *notificationCenter;

@end

@implementation UASceneTracker

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];

    if (self) {
        self.notificationCenter = notificationCenter;
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            self.scenes = [NSMutableArray array];
        }
    }

    if (@available(iOS 13.0, tvOS 13.0, *)) {
        [self observeSceneEvents];
    }

    return self;
}

+ (instancetype)sceneObserver:(NSNotificationCenter *)notificationCenter {
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

- (nullable UIWindowScene *)primaryWindowScene {
    for (UIScene *scene in self.scenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }

    return nil;
}

- (void)sceneAdded:(NSNotification *)notification API_AVAILABLE(ios(13.0)) {
    [self.scenes addObject:notification.object];
}

- (void)sceneRemoved:(NSNotification *)notification API_AVAILABLE(ios(13.0))  {
    [self.scenes removeObject:notification.object];
}

@end
