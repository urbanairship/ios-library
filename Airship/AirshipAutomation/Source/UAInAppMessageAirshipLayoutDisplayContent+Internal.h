/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(InAppMessageAirshipLayoutDisplayContent)
API_AVAILABLE(ios(13.0))
@interface UAInAppMessageAirshipLayoutDisplayContent : UAInAppMessageDisplayContent

/**
 * The layout that can be passed to Thomas.
 */
@property(nonatomic, copy, nonnull) NSDictionary *layout;

/**
 * Factory method for custom dipslay content with JSON.
 *
 * @param json The json object.
 * @param error The optional error.
 *
 * @returns the display content if the json was able to be applied, otherwise nil.
 */
+ (nullable instancetype)displayContentWithJSON:(id)json error:(NSError **)error;


@end

NS_ASSUME_NONNULL_END
