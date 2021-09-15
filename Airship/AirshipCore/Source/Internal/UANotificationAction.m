/* Copyright Airship and Contributors */

#import "UANotificationAction.h"

@interface UANotificationActionIcon ()

@property(nonatomic, copy) NSString *templateImageName;
@property(nonatomic, copy) NSString *systemImageName;

@end

@implementation UANotificationActionIcon

+ (instancetype)iconWithTemplateImageName:(NSString *)templateImageName {
    UANotificationActionIcon *icon = [[UANotificationActionIcon alloc] init];
    icon.templateImageName = templateImageName;

    return icon;
}

+ (instancetype)iconWithSystemImageName:(NSString *)systemImageName {
    UANotificationActionIcon *icon = [[UANotificationActionIcon alloc] init];
    icon.systemImageName = systemImageName;

    return icon;
}

@end

@interface UANotificationAction ()

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign) UANotificationActionOptions options;
@property(nonatomic, strong) UANotificationActionIcon *icon;

@end

@implementation UANotificationAction

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                           options:(UANotificationActionOptions)options {

    return [self initWithIdentifier:identifier title:title options:options icon:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                           options:(UANotificationActionOptions)options
                              icon:(UANotificationActionIcon *)icon {
    self = [super init];

    if (self) {
        self.identifier = identifier;
        self.title = title;
        self.options = options;
        self.icon = icon;
    }

    return self;
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                             options:(UANotificationActionOptions)options {
    return [[self alloc] initWithIdentifier:identifier title:title options:options];
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                             options:(UANotificationActionOptions)options
                                icon:(UANotificationActionIcon *)icon {
    return [[self alloc] initWithIdentifier:identifier title:title options:options icon:icon];
}

#if !TARGET_OS_TV    // UNNotificationAction not available on tvOS
- (UNNotificationAction *)asUNNotificationAction {
#if !TARGET_OS_MACCATALYST
    if (@available(iOS 15.0, *)) {
        UNNotificationActionIcon *icon;

        if (self.icon.systemImageName) {
            icon = [UNNotificationActionIcon iconWithSystemImageName:self.icon.systemImageName];
        } else if (self.icon.templateImageName) {
            icon = [UNNotificationActionIcon iconWithTemplateImageName:self.icon.templateImageName];
        }

        return [UNNotificationAction actionWithIdentifier:self.identifier
                                                     title:self.title
                                                   options:(UNNotificationActionOptions)self.options
                                                      icon:icon];
    } else {
        return [UNNotificationAction actionWithIdentifier:self.identifier
                                                     title:self.title
                                                  options:(UNNotificationActionOptions)self.options];
    }
#else
    return [UNNotificationAction actionWithIdentifier:self.identifier
                                                 title:self.title
                                              options:(UNNotificationActionOptions)self.options];
#endif
}

- (BOOL)isEqualToUNNotificationAction:(UNNotificationAction *)notificationAction {
    BOOL equalIdentifier = [self.identifier isEqualToString:notificationAction.identifier];
    BOOL equalTitle = [self.title isEqualToString:notificationAction.title];
    BOOL equalOptions = (NSUInteger)self.options == (NSUInteger)notificationAction.options;
#if !TARGET_OS_MACCATALYST
    if (@available(iOS 15.0, *)) {
        // Note: UNNotificationActionIcon has no inspectable properties
        BOOL equalIcon = (self.icon && notificationAction.icon) || (!self.icon && !notificationAction.icon);
        return equalIdentifier && equalTitle && equalOptions && equalIcon;
    } else {
        return equalIdentifier && equalTitle && equalOptions;
    }
#else
    return equalIdentifier && equalTitle && equalOptions;
#endif
}
#endif

@end
