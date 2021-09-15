/* Copyright Airship and Contributors */

#import "UATextInputNotificationAction.h"
#import "UANotificationAction.h"

@interface UATextInputNotificationAction ()

@property(nonatomic, copy) NSString *textInputButtonTitle;
@property(nonatomic, copy) NSString *textInputPlaceholder;

@end

@implementation UATextInputNotificationAction

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
              textInputButtonTitle:(NSString *)textInputButtonTitle
              textInputPlaceholder:(NSString *)textInputPlaceholder
                           options:(UANotificationActionOptions)options {

    return [self initWithIdentifier:identifier
                              title:title
               textInputButtonTitle:textInputButtonTitle
               textInputPlaceholder:textInputPlaceholder
                            options:options
                               icon:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
              textInputButtonTitle:(NSString *)textInputButtonTitle
              textInputPlaceholder:(NSString *)textInputPlaceholder
                           options:(UANotificationActionOptions)options
                              icon:(UANotificationActionIcon *)icon {

    self = [super initWithIdentifier:identifier title:title options:options icon:icon];

    if (self) {
        self.textInputButtonTitle = textInputButtonTitle;
        self.textInputPlaceholder = textInputPlaceholder;
    }

    return self;
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                textInputButtonTitle:(NSString *)textInputButtonTitle
                textInputPlaceholder:(NSString *)textInputPlaceholder
                             options:(UANotificationActionOptions)options {

    return [[self alloc] initWithIdentifier:identifier title:title textInputButtonTitle:textInputButtonTitle textInputPlaceholder:textInputPlaceholder options:options];
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                textInputButtonTitle:(NSString *)textInputButtonTitle
                textInputPlaceholder:(NSString *)textInputPlaceholder
                             options:(UANotificationActionOptions)options
                                icon:(UANotificationActionIcon *)icon {

    return [[self alloc] initWithIdentifier:identifier
                                      title:title
                       textInputButtonTitle:textInputButtonTitle
                       textInputPlaceholder:textInputPlaceholder
                                    options:options
                                       icon:icon];
}

#if !TARGET_OS_TV    // UNTextInputNotificationAction not available on tvOS
- (UNTextInputNotificationAction *)asUNNotificationAction {
#if !TARGET_OS_MACCATALYST
    if (@available(iOS 15.0, *)) {
        UNNotificationActionIcon *icon;

        if (self.icon.systemImageName) {
            icon = [UNNotificationActionIcon iconWithSystemImageName:self.icon.systemImageName];
        } else if (self.icon.templateImageName) {
            icon = [UNNotificationActionIcon iconWithTemplateImageName:self.icon.templateImageName];
        }

        return [UNTextInputNotificationAction actionWithIdentifier:self.identifier
                                                             title:self.title
                                                           options:(UNNotificationActionOptions)self.options
                                                              icon:icon
                                              textInputButtonTitle:self.textInputButtonTitle
                                              textInputPlaceholder:self.textInputPlaceholder];
    } else {
        return [UNTextInputNotificationAction actionWithIdentifier:self.identifier
                                                             title:self.title
                                                           options:(UNNotificationActionOptions)self.options
                                              textInputButtonTitle:self.textInputButtonTitle
                                              textInputPlaceholder:self.textInputPlaceholder];

    }

#else
        return [UNTextInputNotificationAction actionWithIdentifier:self.identifier
                                                             title:self.title
                                                           options:(UNNotificationActionOptions)self.options
                                              textInputButtonTitle:self.textInputButtonTitle
                                              textInputPlaceholder:self.textInputPlaceholder];
#endif
}
#endif

@end
