/* Copyright 2018 Urban Airship and Contributors */

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
 */
@property(nonatomic, strong) UAInAppMessageTextInfo *label;

/**
 * Button identifier. Required. Must be between [1-100] characters.
 */
@property(nonatomic, copy) NSString *identifier;

/**
 * Button tap behavior. Defaults to UAInAppMessageButtonInfoBehaviorDismiss.
 */
@property(nonatomic, assign) UAInAppMessageButtonInfoBehaviorType behavior;

/**
 * Button border radius. Defaults to 0.
 */
@property(nonatomic, assign) NSUInteger borderRadius;

/**
 * Button background color. Defaults to transparent.
 */
@property(nonatomic, strong) UIColor *backgroundColor;

/**
 * Button border color. Defaults to transparent.
 */
@property(nonatomic, strong) UIColor *borderColor;

/**
 * Button actions.
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
@property(nonatomic, assign, readonly) UAInAppMessageButtonInfoBehaviorType behavior;

/**
 * Button border radius. Defaults to 0.
 */
@property(nonatomic, assign, readonly) NSUInteger borderRadius;

/**
 * Button background color. Defaults to transparent.
 */
@property(nonatomic, strong, readonly, nullable) UIColor *backgroundColor;

/**
 * Button border color. Defaults to transparent.
 */
@property(nonatomic, strong, readonly, nullable) UIColor *borderColor;

/**
 * Button actions.
 */
@property(nonatomic, copy, readonly, nullable) NSDictionary *actions;


/**
 * Creates an in-app message button info with a builder block.
 *
 * @return The in-app message button info if the builder sucessfully built it, otherwise nil.
 */
+ (nullable instancetype)buttonInfoWithBuilderBlock:(void(^)(UAInAppMessageButtonInfoBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

