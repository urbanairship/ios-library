
#import "UASceneTracker+Internal.h"

@interface UASceneTracker ()

@property(nonatomic, strong) NSMutableArray *scenes;
@property(nonatomic, strong) NSNotificationCenter *notificationCenter;

@end

@implementation UASceneTracker

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super init];

    if (self) {
        self.notificationCenter = notificationCenter;
        self.scenes = [NSMutableArray array];
    }

    [self observeSceneEvents];

    return self;
}

+ (instancetype)sceneObserver:(NSNotificationCenter *)notificationCenter {
    return [[self alloc] initWithNotificationCenter:notificationCenter];
}

- (void)observeSceneEvents {
    if (@available(iOS 13.0, *)) {
        [self.notificationCenter addObserver:self
                                    selector:@selector(sceneAdded:) name:UISceneWillConnectNotification
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(sceneRemoved:)
                                        name:UISceneWillDeactivateNotification
                                      object:nil];
    }
}

- (NSArray<UIScene *>*)scenes  API_AVAILABLE(ios(13.0)){
    return [NSArray arrayWithArray:_scenes];
}

- (nullable UIWindowScene *)primaryWindowScene {
    for (UIScene *scene in _scenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }

    return nil;
}

- (void)sceneAdded:(NSNotification *)notification {
    [_scenes addObject:notification.object];
}

- (void)sceneRemoved:(NSNotification *)notification  {
    [_scenes removeObject:notification.object];
}

- (void)dealloc {
    [self.notificationCenter removeObserver:self];
}

@end
