/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageModalDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing display content from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageModalDisplayContentErrorCode) {
    /**
     * Indicates an error with the display content info JSON definition.
     */
    UAInAppMessageModalDisplayContentErrorCodeInvalidJSON,
};

@interface UAInAppMessageModalDisplayContent ()

/**
 * Factory method for building modal display content with JSON.
 *
 * @param json The json object.
 * @param error The optional error.
 *
 * @returns the display content if the json was able to be applied, otherwise nil.
 */
+ (nullable instancetype)displayContentWithJSON:(id)json error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END


