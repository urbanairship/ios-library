
#import "UAMutableUserNotificationCategory.h"

@interface UAMutableUserNotificationCategory ()
@property(nonatomic, strong) NSMutableDictionary *actions;
@end

@implementation UAMutableUserNotificationCategory

@dynamic identifier;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.actions = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setActions:(NSArray *)actions forContext:(UAUserNotificationActionContext)context {
    [self.actions setObject:actions forKey:@(context)];
}

@end
