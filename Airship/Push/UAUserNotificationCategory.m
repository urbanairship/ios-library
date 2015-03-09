
#import "UAUserNotificationCategory.h"

@interface UAUserNotificationCategory ()
@property(nonatomic, copy) NSString *identifier;
@end

@implementation UAUserNotificationCategory

- (NSArray *)actionsForContext:(UAUserNotificationActionContext)context {
    return nil;
}

@end
