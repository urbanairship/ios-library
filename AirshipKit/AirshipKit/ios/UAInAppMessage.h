/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Builder class for a UAInAppMessage.
 */
@interface UAInAppMessageBuilder : NSObject

///---------------------------------------------------------------------------------------
/// @name In App Message Builder Properties
///---------------------------------------------------------------------------------------

/**
* The unique identifier for the message.
*/
@property(nonatomic, copy, nullable) NSString *identifier;

/**
 * The display type.
 */
@property(nonatomic, copy) NSString *displayType;

/**
 * The display content for the message.
 */
@property(nonatomic, copy, nullable) id displayContent;

/**
 * The extras for the messages.
 */
@property(nonatomic, copy, nullable) NSDictionary *extras;

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
@property(nonatomic, copy, nullable) NSString *identifier;

/**
 * The display type.
 */
@property(nonatomic, copy) NSString *displayType;

/**
 * The display content for the message.
 */
@property(nonatomic, copy, nullable) id displayContent;

/**
 * The extras for the messages.
 */
@property(nonatomic, copy, nullable) NSDictionary *extras;

/**
 * Class factory method for constructing an unconfigured
 * in-app message model.
 *
 * @return An unconfigured instance of UAInAppMessage.
 */
+ (instancetype)message;

/**
 * Class factory method for constructing an in-app message from JSON.
 *
 * @param json JSON object that defines the message.
 * @return A fully configured instance of UAInAppMessage.
 */
+ (instancetype)messageWithJSON:(NSDictionary *)json;

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
