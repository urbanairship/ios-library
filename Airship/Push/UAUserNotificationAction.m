
#import "UAUserNotificationAction.h"

@interface UAUserNotificationAction ()

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign) UAUserNotificationActivationMode activationMode;
@property(nonatomic, assign, getter=isAuthenticationRequired) BOOL authenticationRequired;
@property(nonatomic, assign, getter=isDestructive) BOOL destructive;

@end

@implementation UAUserNotificationAction

- (BOOL)isAuthenticationRequired {
    if (self.activationMode == UAUserNotificationActivationModeForeground) {
        return YES;
    }
    return _authenticationRequired;
}

- (BOOL)isDestructive {
    return _destructive;
}

@end
