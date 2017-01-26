/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
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

#import "UAUtils.h"
#import "UAUtilsTest.h"

@interface UAUtilsTest ()
@property(nonatomic, strong) NSCalendar *gregorianUTC;
@end

@implementation UAUtilsTest

- (void)setUp {
    [super setUp];
    self.gregorianUTC = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSGregorianCalendar];

    self.gregorianUTC.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
}

- (void)tearDown {
    [super tearDown];
}

- (NSDateComponents *)componentsForDate:(NSDate *)date {
    return [self.gregorianUTC components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:date];
}

- (void)validateDateFormatter:(NSDateFormatter *)dateFormatter withFormatString:(NSString *)formatString {
    NSDate *date = [dateFormatter dateFromString:formatString];

    NSDateComponents *components = [self componentsForDate:date];

    XCTAssertEqual(components.year, 2020);
    XCTAssertEqual(components.month, 12);
    XCTAssertEqual(components.day, 15);
    XCTAssertEqual(components.hour, 11);
    XCTAssertEqual(components.minute, 45);
    XCTAssertEqual(components.second, 22);

    XCTAssertEqualObjects(formatString, [dateFormatter stringFromDate:date]);

}

- (void)testISODateFormatterUTC {
    [self validateDateFormatter:[UAUtils ISODateFormatterUTC] withFormatString: @"2020-12-15 11:45:22"];
}

- (void)testISODateFormatterUTCWithDelimiter {
    [self validateDateFormatter:[UAUtils ISODateFormatterUTCWithDelimiter] withFormatString: @"2020-12-15T11:45:22"];
}

/**
 * Test isSilentPush is YES when no notification alerts exist in the payload.
 */
- (void)testIsSilentPush {

    NSDictionary *emptyNotification = @{
                                        @"aps": @{
                                                @"content-available": @1
                                                }
                                        };

    NSDictionary *emptyAlert = @{
                                 @"aps": @{
                                         @"alert": @""
                                         }
                                 };

    NSDictionary *emptyLocKey = @{
                                         @"aps": @{
                                                 @"alert": @{
                                                         @"loc-key": @""
                                                         }
                                                 }
                                         };

    NSDictionary *emptyBody = @{
                                       @"aps": @{
                                               @"alert": @{
                                                       @"body": @""
                                                       }
                                               }
                                       };
    XCTAssertTrue([UAUtils isSilentPush:emptyNotification]);
    XCTAssertTrue([UAUtils isSilentPush:emptyAlert]);
    XCTAssertTrue([UAUtils isSilentPush:emptyLocKey]);
    XCTAssertTrue([UAUtils isSilentPush:emptyBody]);


}

/**
 * Test testIsSilentPush is NO when at least one notification alert exist in the payload.
 */
- (void)testIsSilentPushNo {

    NSDictionary *alertNotification = @{
                                        @"aps": @{
                                                @"alert": @"hello world"
                                                }
                                        };

    NSDictionary *badgeNotification = @{
                                        @"aps": @{
                                                @"badge": @2
                                                }
                                        };

    NSDictionary *soundNotification = @{
                                        @"aps": @{
                                                @"sound": @"cat"
                                                }
                                        };

    NSDictionary *notification = @{
                                   @"aps": @{
                                           @"alert": @"hello world",
                                           @"badge": @2,
                                           @"sound": @"cat"
                                           }
                                   };

    NSDictionary *locKeyNotification = @{
                                         @"aps": @{
                                                 @"alert": @{
                                                         @"loc-key": @"cool"
                                                         }
                                                 }
                                         };

    NSDictionary *bodyNotification = @{
                                         @"aps": @{
                                                 @"alert": @{
                                                         @"body": @"cool"
                                                         }
                                                 }
                                         };


    XCTAssertFalse([UAUtils isSilentPush:alertNotification]);
    XCTAssertFalse([UAUtils isSilentPush:badgeNotification]);
    XCTAssertFalse([UAUtils isSilentPush:soundNotification]);
    XCTAssertFalse([UAUtils isSilentPush:notification]);
    XCTAssertFalse([UAUtils isSilentPush:locKeyNotification]);
    XCTAssertFalse([UAUtils isSilentPush:bodyNotification]);
}




@end
