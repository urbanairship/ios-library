/* Copyright Urban Airship and Contributors */

#import "UANotificationAction.h"

@interface UANotificationAction ()

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign) UANotificationActionOptions options;

@end

@implementation UANotificationAction

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                           options:(UANotificationActionOptions)options {
    self = [super init];

    if (self) {
        self.identifier = identifier;
        self.title = title;
        self.options = options;
    }
    return self;
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                             options:(UANotificationActionOptions)options {
    return [[self alloc] initWithIdentifier:identifier title:title options:options];
}

#if !TARGET_OS_TV    //UNNotificationAction not available on tvOS
- (UNNotificationAction *)asUNNotificationAction {
    return [UNNotificationAction actionWithIdentifier:self.identifier
                                                title:self.title
                                              options:(UNNotificationActionOptions)self.options];
}

- (BOOL)isEqualToUNNotificationAction:(UNNotificationAction *)notificationAction {
    BOOL equalIdentifier = [self.identifier isEqualToString:notificationAction.identifier];
    BOOL equalTitle = [self.title isEqualToString:notificationAction.title];
    BOOL equalOptions = (NSUInteger)self.options == (NSUInteger)notificationAction.options;

    return equalIdentifier && equalTitle && equalOptions;
}
#endif

@end
