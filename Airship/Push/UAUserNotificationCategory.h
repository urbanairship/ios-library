
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, UAUserNotificationActionContext) {
    UAUserNotificationActionContextDefault,  // the default context of a notification action
    UAUserNotificationActionContextMinimal   // the context of a notification action when space is limited
};

@interface UAUserNotificationCategory : NSObject

- (NSArray *)actionsForContext:(UAUserNotificationActionContext)context;

@property(nonatomic, copy, readonly) NSString *identifier;

@end
