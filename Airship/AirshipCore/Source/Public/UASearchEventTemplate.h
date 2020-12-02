/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UACustomEvent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A UASearchEventTemplate represents a custom search event template for the
 * application.
 */
@interface UASearchEventTemplate : NSObject

///---------------------------------------------------------------------------------------
/// @name Search Event Template Properties
///---------------------------------------------------------------------------------------

/**
 * The event's value. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
*/
@property (nonatomic, strong, nullable) NSDecimalNumber *eventValue;

/**
 * The event's type.
 */
@property (nonatomic, copy, nullable) NSString *type;

/**
 * The event's identifier.
 */
@property (nonatomic, copy, nullable) NSString *identifier;

/**
 * The event's category.
 */
@property (nonatomic, copy, nullable) NSString *category;

/**
 * The event's query. 
 */
@property (nonatomic, copy, nullable) NSString *query;

/**
 * The event's total results.
 */
@property (nonatomic) NSInteger totalResults;

///---------------------------------------------------------------------------------------
/// @name Search Event Template Factories
///---------------------------------------------------------------------------------------

/**
 * Factory method for creating a search event template.
 * @return UASearchEventTemplate instance.
 */
+ (instancetype)template;

/**
 * Factory method for creating a search event template with a value.
 *
 * @param eventValue The value of the event. The value must be between -2^31 and
 * 2^31 - 1 or it will invalidate the event.
 * @return UASearchEventTemplate instance.
 */
+ (instancetype)templateWithValue:(nullable NSNumber *)eventValue;

/**
 * Creates the custom search event.
 * @return Created UACustomEvent instance.
 */
- (UACustomEvent *)createEvent;

@end

NS_ASSUME_NONNULL_END
