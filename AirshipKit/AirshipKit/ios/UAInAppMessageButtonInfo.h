/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageTextInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing button info from JSON.
 */
typedef NS_ENUM(NSInteger, UAButtonInfoErrorCode) {
    /**
     * Indicates an error with the button info JSON definition.
     */
    UAInAppMessageButtonInfoErrorCodeInvalidJSON,
};

/**
 * JSON key.
 */
extern NSString *const UAInAppMessageButtonInfoLabelKey;
extern NSString *const UAInAppMessageButtonInfoIdentifierKey;
extern NSString *const UAInAppMessageButtonInfoBehaviorKey;
extern NSString *const UAInAppMessageButtonInfoBorderRadiusKey;
extern NSString *const UAInAppMessageButtonInfoBackgroundColorKey;
extern NSString *const UAInAppMessageButtonInfoBorderColorKey;
extern NSString *const UAInAppMessageButtonInfoActionsKey;

/**
 * Cancels the in-app message's schedule when clicked.
 */
extern NSString *const UAInAppMessageButtonInfoBehaviorCancel;

/**
 * Dismisses the in-app message when clicked.
 */
extern NSString *const UAInAppMessageButtonInfoBehaviorDismiss;


/**
 * Builder class for an UAInAppMessageButtonInfo object.
 */
@interface UAInAppMessageButtonInfoBuilder : NSObject

/**
 * Button label.
 */
@property(nonatomic, strong) UAInAppMessageTextInfo *label;

/**
 * Button identifier.
 */
@property(nonatomic, copy) NSString *identifier;

/**
 * Button tap behavior. Defaults to UAInAppMessageButtonInfoBehaviorDismiss.
 */
@property(nonatomic, copy) NSString *behavior;

/**
 * Button border radius. Defaults to 0.
 */
@property(nonatomic, assign) NSUInteger borderRadius;

/**
 * Button background color. Defaults to transparent.
 */
@property(nonatomic, copy) NSString *backgroundColor;

/**
 * Button border color. Defaults to transparent.
 */
@property(nonatomic, copy) NSString *borderColor;

/**
 * Button actions.
 */
@property(nonatomic, copy, nullable) NSDictionary *actions;

@end


/**
 * Defines an in-app message button.
 */
@interface UAInAppMessageButtonInfo : NSObject

/**
 * Button label.
 */
@property(nonatomic, strong, readonly, nullable) UAInAppMessageTextInfo *label;

/**
 * Button identifier.
 */
@property(nonatomic, copy, readonly, nullable) NSString *identifier;

/**
 * Button tap behavior. Defaults to UAInAppMessageButtonInfoBehaviorDismiss.
 */
@property(nonatomic, copy, readonly, nullable) NSString *behavior;

/**
 * Button border radius. Defaults to 0.
 */
@property(nonatomic, assign, readonly) NSUInteger borderRadius;

/**
 * Button background color. Defaults to transparent.
 */
@property(nonatomic, copy, readonly, nullable) NSString *backgroundColor;

/**
 * Button border color. Defaults to transparent.
 */
@property(nonatomic, copy, readonly, nullable) NSString *borderColor;

/**
 * Button actions.
 */
@property(nonatomic, copy, readonly, nullable) NSDictionary *actions;

/**
 * Factory method to create an in-app message button info from a JSON payload.
 *
 * @param json The JSON payload.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An in-app message button info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)buttonInfoWithJSON:(id)json error:(NSError * _Nullable *)error;

/**
 * Factory method to create a JSON dictionary from an in-app message button info.
 *
 * @param buttonInfo An in-app message button info.
 * @return The JSON dictionary.
 */
+ (NSDictionary *)JSONWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo;

/**
 * Creates an in-app message button info with a builder block.
 *
 * @return The in-app message button info.
 */
+ (nullable instancetype)buttonInfoWithBuilderBlock:(void(^)(UAInAppMessageButtonInfoBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

