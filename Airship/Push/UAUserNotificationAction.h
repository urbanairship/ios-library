
#import <Foundation/Foundation.h>

typedef enum UAUserNotificationActivationMode : NSUInteger {
    UAUserNotificationActivationModeForeground,
    UAUserNotificationActivationModeBackground
} UAUserNotificationActivationMode;

@interface UAUserNotificationAction : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, assign, readonly) UAUserNotificationActivationMode activationMode;
@property(nonatomic, assign, readonly, getter=isAuthenticationRequired) BOOL authenticationRequired;
@property(nonatomic, assign, readonly, getter=isDestructive) BOOL destructive;

@end
