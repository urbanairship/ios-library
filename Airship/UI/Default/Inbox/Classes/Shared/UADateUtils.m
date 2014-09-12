/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UADateUtils.h"

@implementation UADateUtils

static NSDateFormatter *dateFormatter;
static NSDateFormatter *sameDayFormatter;


+ (NSString *)formattedDateRelativeToNow:(NSDate *)date {

    if ([self isDate:date inSameCalendarDayAsDate:[NSDate date]]) {
        if (!sameDayFormatter) {
            sameDayFormatter = [[NSDateFormatter alloc] init];
            sameDayFormatter.timeStyle = NSDateFormatterShortStyle;
            sameDayFormatter.dateStyle = NSDateFormatterShortStyle;
            sameDayFormatter.doesRelativeDateFormatting = YES;
        }

        return [sameDayFormatter stringFromDate:date];
    } else {
        if (!dateFormatter) {
            dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.timeStyle = NSDateFormatterNoStyle;
            dateFormatter.dateStyle = NSDateFormatterShortStyle;
            dateFormatter.doesRelativeDateFormatting = YES;
        }

        return [dateFormatter stringFromDate:date];
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
