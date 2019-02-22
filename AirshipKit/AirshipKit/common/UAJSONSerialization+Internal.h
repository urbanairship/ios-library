/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "NSJSONSerialization+UAAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAJSONSerialization : NSObject

/**
 * Wrapper around NSJSONSerialization's dataWithJSONObject:options: that checks if the JSON object is
 * serializable prior to attempting to serialize. This is to avoid crashing when serialization is attempted
 * on an invalid JSON object.
 *
 * @param obj JSON object to serialize into data.
 * @param opt NSJSONWritingOptions for serialization.
 * @param error Error to populate if object validation fails.
 * @return The serialized data if JSON object is valid, otherwise nil.
 */
+ (nullable NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
