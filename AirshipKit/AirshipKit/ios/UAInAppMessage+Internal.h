/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing an in-app message from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageErrorCode) {
    /**
     * Indicates an error with the in-app message JSON definition.
     */
    UAInAppMessageErrorCodeInvalidJSON,
};

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
 * Class factory method for constructing an in-app message from JSON.
 *
 * @param json JSON object that defines the message.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return A fully configured instance of UAInAppMessage or nil if JSON parsing fails.
 */
+ (nullable instancetype)messageWithJSON:(NSDictionary *)json error:(NSError * _Nullable *)error;

/**
 * Method to return the message as its JSON representation.
 *
 * @returns JSON representation of message (as NSDictionary)
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END
