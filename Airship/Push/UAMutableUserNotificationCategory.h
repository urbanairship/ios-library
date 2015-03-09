
#import "UAUserNotificationCategory.h"

@interface UAMutableUserNotificationCategory : UAUserNotificationCategory

- (void)setActions:(NSArray *)actions
        forContext:(UAUserNotificationActionContext)context;

@property(nonatomic, copy) NSString *identifier;

@end
