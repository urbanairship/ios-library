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

#import "UAInAppResolutionEvent+Internal.h"
#import "UAInAppMessage.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAEvent+Internal.h"
#import "UAUtils.h"

@implementation UAInAppResolutionEvent

- (instancetype) initWithMessage:(UAInAppMessage *)message resolution:(NSDictionary *)resolution {
    self = [super init];
    if (self) {
        NSMutableDictionary *data = [NSMutableDictionary dictionary];
        [data setValue:message.identifier forKey:@"id"];
        [data setValue:[UAirship shared].analytics.conversionSendID forKey:@"conversion_send_id"];
        [data setValue:[UAirship shared].analytics.conversionPushMetadata forKey:@"conversion_metadata"];
        [data setValue:resolution forKey:@"resolution"];

        self.data = [data copy];
        return self;
    }
    return nil;
}


- (NSString *)eventType {
    return @"in_app_resolution";
}

- (BOOL)isValid {
    return self.data[@"id"] != nil;
}

+ (instancetype)expiredMessageResolutionWithMessage:(UAInAppMessage *)message {
    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"expired" forKey:@"type"];

    NSDateFormatter *formatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    [resolution setValue:[formatter stringFromDate:message.expiry] forKey:@"expiry"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}

+ (instancetype)replacedResolutionWithMessage:(UAInAppMessage *)message
                                  replacement:(UAInAppMessage *)replacement {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"replaced" forKey:@"type"];
    [resolution setValue:replacement.identifier forKey:@"replacement_id"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}


+ (instancetype)buttonClickedResolutionWithMessage:(UAInAppMessage *)message
                                  buttonIdentifier:(NSString *)buttonID
                                       buttonTitle:(NSString *)buttonTitle
                                   displayDuration:(NSTimeInterval)duration {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"button_click" forKey:@"type"];
    [resolution setValue:buttonID forKey:@"button_id"];
    [resolution setValue:buttonTitle forKey:@"button_description"];
    [resolution setValue:message.buttonGroup forKey:@"button_group"];
    [resolution setValue:[NSString stringWithFormat:@"%.3f", duration] forKey:@"display_time"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}

+ (instancetype)messageClickedResolutionWithMessage:(UAInAppMessage *)message
                                    displayDuration:(NSTimeInterval)duration {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"message_click" forKey:@"type"];
    [resolution setValue:[NSString stringWithFormat:@"%.3f", duration] forKey:@"display_time"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}


+ (instancetype)dismissedResolutionWithMessage:(UAInAppMessage *)message
                               displayDuration:(NSTimeInterval)duration {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"user_dismissed" forKey:@"type"];
    [resolution setValue:[NSString stringWithFormat:@"%.3f", duration] forKey:@"display_time"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}


+ (instancetype)timedOutResolutionWithMessage:(UAInAppMessage *)message
                              displayDuration:(NSTimeInterval)duration {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"timed_out" forKey:@"type"];
    [resolution setValue:[NSString stringWithFormat:@"%.3f", duration] forKey:@"display_time"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}

+ (instancetype)directOpenResolutionWithMessage:(UAInAppMessage *)message {
    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"direct_open" forKey:@"type"];

    return [[self alloc] initWithMessage:message resolution:resolution];}

@end
