/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UAInAppMessageTextInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Button behavior.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageButtonInfoBehaviorType) {
    /**
     * Dismiss behavior
     */
    UAInAppMessageButtonInfoBehaviorDismiss,
    
    /**
     * Cancel behavior
     */
    UAInAppMessageButtonInfoBehaviorCancel,
    
};

/**
 * Button identifier limit (100 characters).
 */
extern NSUInteger const UAInAppMessageButtonInfoIDLimit;


/**
 * Builder class for UAInAppMessageButtonInfo.
 */
@interface UAInAppMessageButtonInfoBuilder : NSObject

/**
 * Button label.
 *
 * Required
 */
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *label;

/**
 * Button identifier.
 *
 * Required. Must be between [1-100] characters.
 */
@property(nonatomic, copy, nullable) NSString *identifier;

/**
 * Button tap behavior.
 *
 * Optional. Defaults to UAInAppMessageButtonInfoBehaviorDismiss.
 */
@property(nonatomic, assign) UAInAppMessageButtonInfoBehaviorType behavior;

/**
 * The button's border radius.
 *
 * Optional. Defaults to 0.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `borderRadiusPoints`.
 */
@property(nonatomic, assign) NSUInteger borderRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use borderRadiusPoints.");

/**
 * The button's border radius. Use to set the border radius
 * to non-integer values.
 *
 * Optional. Defaults to 0.
 */
@property(nonatomic, assign) CGFloat borderRadiusPoints;

/**
 * Button background color.
 *
 * Optional. Defaults to transparent.
 */
@property(nonatomic, strong) UIColor *backgroundColor;

/**
 * Button border color.
 *
 * Optional. Defaults to transparent.
 */
@property(nonatomic, strong) UIColor *borderColor;

/**
 * Button actions.
 *
 * Optional.
 */
@property(nonatomic, copy, nullable) NSDictionary *actions;

/**
 * Checks if the builder is valid and will produce a text info instance.
 * @return YES if the builder is valid (requires label and id), otherwise NO.
 */
- (BOOL)isValid;

@end


/**
 * Defines an in-app message button.
 *
 * @note This object is built using `UAInAppMessageButtonInfoBuilder`.
 */
@interface UAInAppMessageButtonInfo : NSObject

/**
 * Button label.
 */
@property(nonatomic, readonly) UAInAppMessageTextInfo *label;

/**
 * Button identifier.
 */
@property(nonatomic, readonly) NSString *identifier;

/**
 * Button tap behavior.
 */
@property(nonatomic, readonly) UAInAppMessageButtonInfoBehaviorType behavior;

/**
 * The button's border radius.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `borderRadiusPoints`.
 */
@property(nonatomic, readonly) NSUInteger borderRadius DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use borderRadiusPoints.");

/**
 * The button's border radius. Use to set the border radius
 * to non-integer values.
 */
@property(nonatomic, readonly) CGFloat borderRadiusPoints;

/**
 * Button background color.
 */
@property(nonatomic, readonly) UIColor *backgroundColor;

/**
 * Button border color.
 */
@property(nonatomic, readonly) UIColor *borderColor;

/**
 * Button actions.
 */
@property(nonatomic, nullable, readonly) NSDictionary *actions;

/**
 * Creates an in-app message button info with a builder block.
 *
 * @return The in-app message button info if the builder sucessfully built it, otherwise nil.
 */
+ (nullable instancetype)buttonInfoWithBuilderBlock:(void(^)(UAInAppMessageButtonInfoBuilder *builder))builderBlock;

/**
 * Extends an in-app message button info with a builder block.
 *
 * @param builderBlock The builder block.
 * @return An extended instance of UAInAppMessageButtonInfo.
 */
- (nullable UAInAppMessageButtonInfo *)extend:(void(^)(UAInAppMessageButtonInfoBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

