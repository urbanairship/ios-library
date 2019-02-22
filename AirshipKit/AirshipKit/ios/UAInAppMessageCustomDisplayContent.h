/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Display content for a custom in-app message.
 */
@interface UAInAppMessageCustomDisplayContent : UAInAppMessageDisplayContent

/**
 * The custom content.
 *
 * Optional.
 */
@property (nonatomic, readonly) NSDictionary *value;

/**
 * Factory method to create a custom display content.
 *
 * @param value The custom display content. The value should be json serializable.
 * @return The custom display content.
 */
+ (instancetype)displayContentWithValue:(NSDictionary *)value;

@end

NS_ASSUME_NONNULL_END

