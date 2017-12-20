/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Builder class for a UAInAppMessage.
 */
@interface UAInAppMessageBuilder ()

/**
 * JSON object representing the entire in-app message.
 */
@property(nonatomic, strong) NSDictionary *json;

@end

/**
 * Model object representing in-app message data.
 */
@interface UAInAppMessage ()

/**
 * In-app message json keys and values.
 */
extern NSString *const UAInAppMessageIDKey;
extern NSString *const UAInAppMessageDisplayTypeKey;
extern NSString *const UAInAppMessageDisplayContentKey;
extern NSString *const UAInAppMessageExtrasKey;
extern NSString *const UAInAppMessageAudienceKey;

extern NSString *const UAInAppMessageDisplayTypeBannerValue;
extern NSString *const UAInAppMessageDisplayTypeFullScreenValue;
extern NSString *const UAInAppMessageDisplayTypeModalValue;
extern NSString *const UAInAppMessageDisplayTypeHTMLValue;
extern NSString *const UAInAppMessageDisplayTypeCustomValue;

/**
 * JSON object representing the entire in-app message.
 */
@property(nonatomic, strong) NSDictionary *json;

@end

NS_ASSUME_NONNULL_END
