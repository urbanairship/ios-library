/* Copyright Urban Airship and Contributors */

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
    self = [super initWithIdentifier:identifier title:title options:options];

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

#if !TARGET_OS_TV    // UNTextInputNotificationAction not available on tvOS
- (UNTextInputNotificationAction *)asUNNotificationAction {
    return [UNTextInputNotificationAction actionWithIdentifier:self.identifier
                                                title:self.title
                                              options:(UNNotificationActionOptions)self.options
                                          textInputButtonTitle:self.textInputButtonTitle
                                          textInputPlaceholder:self.textInputPlaceholder];
}
#endif

@end
