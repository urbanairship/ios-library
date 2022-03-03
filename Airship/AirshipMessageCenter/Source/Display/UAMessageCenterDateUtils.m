/* Copyright Airship and Contributors */

#import "UAMessageCenterDateUtils.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@implementation UAMessageCenterDateUtils

/**
 * Formats the provided date into a string relative to the current date.
 * e.g. Today, 1:23 PM vs. mm/dd/yy
 *
 * @param date The date to format relative to the current date.
 * @return A formatted date string. 
 */
+ (NSString *)formattedDateRelativeToNow:(NSDate *)date {

    if ([self isDate:date inSameCalendarDayAsDate:[NSDate date]]) {
        return [UADateFormatter stringFromDate:date format:UADateFormatterFormatRelativeShort];
    } else {
        return [UADateFormatter stringFromDate:date format:UADateFormatterFormatRelativeShortDate];
    }
}

/**
 * A helper method to determine if two dates fall on the same calendar.
 *
 * @param date A date to compare.
 * @param otherDate The other date to compare.
 * @return YES if the dates fall on the same calendar day, else NO.
 */
+ (BOOL)isDate:(NSDate *)date inSameCalendarDayAsDate:(NSDate *)otherDate {
    NSCalendar *calendar = [NSCalendar currentCalendar];

    NSUInteger components = ( NSCalendarUnitYear |
                             NSCalendarUnitMonth |
                             NSCalendarUnitDay);

    NSDateComponents *dateComponents = [calendar components:components fromDate:date];
    NSDateComponents *otherDateComponents = [calendar components:components fromDate:otherDate];

    return (dateComponents.day == otherDateComponents.day &&
            dateComponents.month == otherDateComponents.month &&
            dateComponents.year == otherDateComponents.year);
}

@end
