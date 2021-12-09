
#import "UAInAppMessage+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Util methods for in-app message events.
 */
@interface UAInAppMessageEventUtils : NSObject

/**
 * Creates common event data for dispaly and resolution events.
 *
 *
 * @param messageID The message ID.
 * @param source The message source.
 * @param campaigns The campaigns info.
 * @param context The reporting context.
 * @return In-app message event data.
 */
+ (NSMutableDictionary *)createDataWithMessageID:(NSString *)messageID
                                          source:(UAInAppMessageSource)source
                                       campaigns:(nullable NSDictionary  *)campaigns
                                         context:(nullable NSDictionary *)context;

/**
 * Creates common event data.
 *
 *
 * @param message The message.
 * @param messageID The message ID.
 * @param context The reporting context.
 * @param campaigns The campiagns info.
 * @return In-app message event data.
 */
+ (NSMutableDictionary *)createDataWithMessage:(UAInAppMessage *)message
                                     messageID:(NSString *)messageID
                                       context:(NSDictionary *)context
                                     campaigns:(NSDictionary *)campaigns;

@end

NS_ASSUME_NONNULL_END

