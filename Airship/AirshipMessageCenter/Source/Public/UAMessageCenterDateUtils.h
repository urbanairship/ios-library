/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Utility for getting relative date within the message center.
 */
NS_SWIFT_NAME(MessageCenterDateUtils)
@interface UAMessageCenterDateUtils : NSObject

///---------------------------------------------------------------------------------------
/// @name Message Center Date Utils Core Methods
///---------------------------------------------------------------------------------------

+ (NSString *)formattedDateRelativeToNow:(NSDate *)date;

@end
