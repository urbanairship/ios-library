/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleInfo.h"
#import "UAInAppMessageScheduleInfo.h"
#import "UAInAppMessage+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageScheduleInfo ()


/**
 * Factory method to create an in-app message schedule info from a JSON payload.
 *
 * @param json The JSON payload.
 * @param source The in-app message source.
 * @return An in-app message schedule info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)scheduleInfoWithJSON:(id)json
                                       source:(UAInAppMessageSource)source
                                        error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END

