/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Message name limit (100 characters).
 */
extern NSUInteger const UAInAppMessageNameLimit;

/**
 * The in-app message default display behavior. Usually displayed using the default coordinator
 * that allows defining display interval.
 */
extern NSString *const UAInAppMessageDisplayBehaviorDefault;

/**
 * The in-app message should be displayed ASAP.
 */
extern NSString *const UAInAppMessageDisplayBehaviorImmediate;

/**
 * Builder class for UAInAppMessage.
 */
@interface UAInAppMessageBuilder : NSObject

///---------------------------------------------------------------------------------------
/// @name In App Message Builder Properties
///---------------------------------------------------------------------------------------

/**
 * Message name. Optional. Must be between [1-100] characters.
 */
@property(nonatomic, copy, nullable) NSString *name;
/**
 * The display content for the message.
 *
 * Required.
 */
@property(nonatomic, strong, nullable) UAInAppMessageDisplayContent *displayContent;

/**
 * Extra information for the message.
 *
 * Optional.
 */
@property(nonatomic, copy, nullable) NSDictionary *extras;

/**
 * The display actions for the message.
 *
 * Optional.
 */
@property(nonatomic, copy, nullable) NSDictionary *actions;

/**
 * Display behavior. Defaults to UAInAppMessageDisplayBehaviorDefault.
 */
@property(nonatomic, copy, nullable) NSString *displayBehavior;

/**
 * Flag indicating if reporting is enabled. Defaults to `NO`.
 */
@property(nonatomic, assign) BOOL isReportingEnabled;

/**
 * Checks if the builder is valid and will produce a message instance.
 * @return YES if the builder is valid (requires display content and an ID), otherwise NO.
 */
- (BOOL)isValid;

@end

/**
 * Model object representing in-app message data.
 *
 * @note This object is built using `UAInAppMessageBuilder`.
 */
NS_SWIFT_NAME(InAppMessage)
@interface UAInAppMessage : NSObject

///---------------------------------------------------------------------------------------
/// @name In App Message Properties
///---------------------------------------------------------------------------------------

/**
 * Message name. Optional. Must be between [1-100] characters.
 */
@property(nonatomic, copy, nullable, readonly) NSString *name;

/**
 * The display type.
 */
@property(nonatomic, readonly) UAInAppMessageDisplayType displayType;

/**
 * The display content for the message.
 */
@property(nonatomic, readonly) UAInAppMessageDisplayContent *displayContent;

/**
 * Extra information for the message.
 */
@property(nonatomic, nullable, readonly) NSDictionary *extras;

/**
 * Display actions.
 */
@property(nonatomic, nullable, readonly) NSDictionary *actions;

/**
 * Display behavior. Defaults to UAInAppMessageDisplayBehaviorDefault.
 */
@property(nonatomic, copy, readonly) NSString *displayBehavior;

/**
 * Flag indicating if reporting is enabled. Defaults to `YES`.
 */
@property(nonatomic, assign, readonly) BOOL isReportingEnabled;

///---------------------------------------------------------------------------------------
/// @name In App Message Methods
///---------------------------------------------------------------------------------------

/**
 * Class factory method for constructing an in-app message
 * model with an in-app message builder block.
 *
 * @param builderBlock the builder block.
 * @return A fully configured instance of UAInAppMessage.
 */
+ (nullable instancetype)messageWithBuilderBlock:(void(^)(UAInAppMessageBuilder *builder))builderBlock;

/**
 * Extends a message with a builder block.
 *
 * @param builderBlock The builder block.
 * @return An extended instance of UAInAppMessage.
 */
- (nullable UAInAppMessage *)extend:(void(^)(UAInAppMessageBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END
