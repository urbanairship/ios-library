/* Copyright Urban Airship and Contributors */

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
 * In-app message source.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageSource) {
    /**
     * In-app message from the remote-data service.
     */
    UAInAppMessageSourceRemoteData,

    /**
     * In-app message was generated from a push in the legacy in-app message manager.
     */
    UAInAppMessageSourceLegacyPush,

    /**
     * In-app message created programmatically by the application.
     */
    UAInAppMessageSourceAppDefined,
};

@interface UAInAppMessageBuilder ()

/**
 * In-app message source.
 */
@property (nonatomic, assign) UAInAppMessageSource source;

/**
 * In-app message campaigns info.
 */
@property (nonatomic, copy) NSDictionary *campaigns;

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
extern NSString *const UAInAppMessageExtraKey;
extern NSString *const UAInAppMessageAudienceKey;
extern NSString *const UAInAppMessageActionsKey;
extern NSString *const UAInAppMessageCampaignsKey;

extern NSString *const UAInAppMessageDisplayTypeBannerValue;
extern NSString *const UAInAppMessageDisplayTypeFullScreenValue;
extern NSString *const UAInAppMessageDisplayTypeModalValue;
extern NSString *const UAInAppMessageDisplayTypeHTMLValue;
extern NSString *const UAInAppMessageDisplayTypeCustomValue;


/**
 * In-app message source.
 */
@property (nonatomic, readonly) UAInAppMessageSource source;

/**
 * In-app message campaigns info.
 */
@property (nonatomic, readonly) NSDictionary *campaigns;

/**
 * Class factory method for constructing an in-app message from JSON.
 *
 * @param json JSON object that defines the message.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return A fully configured instance of UAInAppMessage or nil if JSON parsing fails.
 */
+ (nullable instancetype)messageWithJSON:(NSDictionary *)json error:(NSError * _Nullable *)error;

/**
 * Class factory method for constructing an in-app message from JSON.
 *
 * @param json JSON object that defines the message.
 * @param defaultSource The in-app message source to use if one is not set in the JSON.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return A fully configured instance of UAInAppMessage or nil if JSON parsing fails.
 */
+ (nullable instancetype)messageWithJSON:(NSDictionary *)json
                           defaultSource:(UAInAppMessageSource)defaultSource
                                   error:(NSError * _Nullable *)error;

/**
 * Method to return the message as its JSON representation.
 *
 * @returns JSON representation of message (as NSDictionary)
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END
