/* Copyright 2017 Urban Airship and Contributors */

#import "UALegacyInAppResolutionEvent+Internal.h"
#import "UALegacyInAppMessage.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAEvent+Internal.h"
#import "UAUtils.h"

@implementation UALegacyInAppResolutionEvent

- (instancetype) initWithMessage:(UALegacyInAppMessage *)message resolution:(NSDictionary *)resolution {
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

+ (instancetype)expiredMessageResolutionWithMessage:(UALegacyInAppMessage *)message {
    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"expired" forKey:@"type"];

    NSDateFormatter *formatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    [resolution setValue:[formatter stringFromDate:message.expiry] forKey:@"expiry"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}

+ (instancetype)replacedResolutionWithMessage:(UALegacyInAppMessage *)message
                                  replacement:(UALegacyInAppMessage *)replacement {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"replaced" forKey:@"type"];
    [resolution setValue:replacement.identifier forKey:@"replacement_id"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}


+ (instancetype)buttonClickedResolutionWithMessage:(UALegacyInAppMessage *)message
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

+ (instancetype)messageClickedResolutionWithMessage:(UALegacyInAppMessage *)message
                                    displayDuration:(NSTimeInterval)duration {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"message_click" forKey:@"type"];
    [resolution setValue:[NSString stringWithFormat:@"%.3f", duration] forKey:@"display_time"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}


+ (instancetype)dismissedResolutionWithMessage:(UALegacyInAppMessage *)message
                               displayDuration:(NSTimeInterval)duration {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"user_dismissed" forKey:@"type"];
    [resolution setValue:[NSString stringWithFormat:@"%.3f", duration] forKey:@"display_time"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}


+ (instancetype)timedOutResolutionWithMessage:(UALegacyInAppMessage *)message
                              displayDuration:(NSTimeInterval)duration {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"timed_out" forKey:@"type"];
    [resolution setValue:[NSString stringWithFormat:@"%.3f", duration] forKey:@"display_time"];

    return [[self alloc] initWithMessage:message resolution:resolution];
}

+ (instancetype)directOpenResolutionWithMessage:(UALegacyInAppMessage *)message {
    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"direct_open" forKey:@"type"];

    return [[self alloc] initWithMessage:message resolution:resolution];}

@end
