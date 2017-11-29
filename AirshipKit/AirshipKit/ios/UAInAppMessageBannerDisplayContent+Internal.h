/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Builder class for a UAInAppMessageBannerDisplayContent.
 */
@interface UAInAppMessageBannerDisplayContentBuilder ()

/**
 * Applies fields from a JSON object.
 *
 * @param json The json object.
 * @param error The optional error.
 * @returns `YES` if the json was able to be applied, otherwise `NO`.
 */
- (BOOL)applyFromJSON:(id)json error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END
