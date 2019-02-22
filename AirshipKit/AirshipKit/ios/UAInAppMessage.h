/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"

@class UAInAppMessageAudience;

NS_ASSUME_NONNULL_BEGIN

/**
 * Message identifier limit (100 characters).
 */
extern NSUInteger const UAInAppMessageIDLimit;

/**
 * Message name limit (100 characters).
 */
extern NSUInteger const UAInAppMessageNameLimit;

/**
 * Builder class for UAInAppMessage.
 */
@interface UAInAppMessageBuilder : NSObject

///---------------------------------------------------------------------------------------
/// @name In App Message Builder Properties
///---------------------------------------------------------------------------------------

/**
 * Message identifier. Must be between [1-100] characters.
 *
 * Required.
 */
@property(nonatomic, copy, nullable) NSString *identifier;

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
 * The audience conditions for the message.
 *
 * Optional.
 */
@property(nonatomic, strong, nullable) UAInAppMessageAudience *audience;

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
@interface UAInAppMessage : NSObject

///---------------------------------------------------------------------------------------
/// @name In App Message Properties
///---------------------------------------------------------------------------------------

/**
 * The unique identifier for the message.
 */
@property(nonatomic, readonly) NSString *identifier;

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
 * The audience conditions for the message.
 */
@property(nonatomic, nullable, readonly) UAInAppMessageAudience *audience;

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
