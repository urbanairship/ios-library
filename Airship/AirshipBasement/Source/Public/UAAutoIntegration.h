/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "UAAppIntegrationDelegate.h"

NS_ASSUME_NONNULL_BEGIN
/**
 * Auto app integration.
 * @note For internal use only. :nodoc:
 */
@interface UAAutoIntegration : NSObject

typedef NSString * _Nonnull(^UAMessageBlock)(void);

/**
 * The logger block - isError, function, line, message block
 */
typedef void (^UALoggerBlock)(BOOL, NSString *, NSUInteger, UAMessageBlock);


///---------------------------------------------------------------------------------------
/// @name Auto Integration Internal Methods
///---------------------------------------------------------------------------------------

+ (void)integrateWithDelegate:(id<UAAppIntegrationDelegate>)delegate;
+ (void)setLogger:(UALoggerBlock)loggerBlock;

@end

NS_ASSUME_NONNULL_END
