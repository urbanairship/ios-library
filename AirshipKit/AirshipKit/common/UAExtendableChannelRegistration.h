/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UANotificationResponse.h"
#import "UANotificationContent.h"
#import "UAChannelRegistrationPayload.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^UAChannelRegistrationExtenderCompletionHandler)(UAChannelRegistrationPayload *);
typedef void (^UAChannelRegistrationExtenderBlock)(UAChannelRegistrationPayload *, UAChannelRegistrationExtenderCompletionHandler completionHandler);

/**
 * Internal protocol to extend Channel registration.
 */
@protocol UAExtendableChannelRegistration<NSObject>

@required

/**
 * Adds a block to extend the Channel registration payload.
 * @param extender The channel extender block.
 */
- (void)addChannelExtenderBlock:(UAChannelRegistrationExtenderBlock)extender;

@end

NS_ASSUME_NONNULL_END
