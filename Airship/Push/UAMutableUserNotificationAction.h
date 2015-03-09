
#import "UAUserNotificationAction.h"

@interface UAMutableUserNotificationAction : UAUserNotificationAction

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign) UAUserNotificationActivationMode activationMode;
@property(nonatomic, assign, getter=isAuthenticationRequired) BOOL authenticationRequired;
@property(nonatomic, assign, getter=isDestructive) BOOL destructive;

@end
