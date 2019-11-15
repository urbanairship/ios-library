/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSDictionary<NSString *, NSString *> * _Nullable (^UAAnalyticsHeadersBlock)(void);

/**
 * Internal protocol to extend Channel registration.
 */
@protocol UAExtendableAnalyticsHeaders<NSObject>

@required

/**
 * Adds a block to appends headers to the analytic headers sent when uploading events.
 * @param headerBlock The header block.
 */
- (void)addAnalyticsHeadersBlock:(UAAnalyticsHeadersBlock)headerBlock;

@end

NS_ASSUME_NONNULL_END
