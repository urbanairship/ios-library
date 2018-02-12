/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDisplayContent.h"

@class UAInAppMessageAudience;

NS_ASSUME_NONNULL_BEGIN

/**
 * Message identifier limit (100 characters).
 */
extern NSUInteger const UAInAppMessageIDLimit;

/**
 * Builder class for UAInAppMessage.
 */
@interface UAInAppMessageBuilder : NSObject

///---------------------------------------------------------------------------------------
/// @name In App Message Builder Properties
///---------------------------------------------------------------------------------------

/**
 * Message identifier. Required. Must be between [1-100] characters.
 */
@property(nonatomic, copy, nullable) NSString *identifier;


/**
 * The display content for the message.
 */
@property(nonatomic, strong, nullable) UAInAppMessageDisplayContent *displayContent;

/**
 * The extras for the messages.
 */
@property(nonatomic, copy, nullable) NSDictionary *extras;

/**
* The display actions for the message.
*/
@property(nonatomic, copy, nullable) NSDictionary *actions;

/**
 * The audience conditions for the messages.
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
 */
@interface UAInAppMessage : NSObject

///---------------------------------------------------------------------------------------
/// @name In App Message Properties
///---------------------------------------------------------------------------------------

/**
* The unique identifier for the message.
*/
@property(nonatomic, copy, readonly) NSString *identifier;

/**
 * The display type.
 */
@property(nonatomic, readonly) UAInAppMessageDisplayType displayType;

/**
 * The display content for the message.
 */
@property(nonatomic, strong, readonly) UAInAppMessageDisplayContent *displayContent;

/**
 * The extras for the messages.
 */
@property(nonatomic, copy, nullable, readonly) NSDictionary *extras;

/**
 * Display actons.
 */
@property(nonatomic, copy, nullable, readonly) NSDictionary *actions;

/**
 * The audience conditions for the messages.
 */
@property(nonatomic, strong, nullable, readonly) UAInAppMessageAudience *audience;

/**
 * Class factory method for constructing an in-app message
 * model with an in-app message builder block.
 *
 * @param builderBlock the builder block.
 * @return A fully configured instance of UAInAppMessage.
 */
+ (instancetype)messageWithBuilderBlock:(void(^)(UAInAppMessageBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END
