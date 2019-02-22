/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageResolutionEvent+Internal.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAEvent+Internal.h"
#import "UAUtils+Internal.h"
#import "UAInAppMessageEventUtils+Internal.h"

NSUInteger const MaxButtonDescriptionLength = 30;

NSString *const UAInAppMessageResolutionEventType = @"in_app_resolution";

// Keys
NSString *const UAInAppMessageResolutionEventTypeKey = @"type";
NSString *const UAInAppMessageResolutionEventResolutionKey = @"resolution";
NSString *const UAInAppMessageResolutionEventDisplayTimeKey = @"display_time";
NSString *const UAInAppMessageResolutionEventButtonIDKey = @"button_id";
NSString *const UAInAppMessageResolutionEventButtonDescriptionKey = @"button_description";
NSString *const UAInAppMessageResolutionEventReplacementIDKey = @"replacement_id";
NSString *const UAInAppMessageResolutionEventExpiryKey = @"expiry";

// Resolution types
NSString *const UAInAppMessageResolutionEventReplaced = @"replaced";
NSString *const UAInAppMessageResolutionEventDirectOpen = @"direct_open";
NSString *const UAInAppMessageResolutionEventMessageClick = @"message_click";
NSString *const UAInAppMessageResolutionEventButtonClick = @"button_click";
NSString *const UAInAppMessageResolutionEventUserDismissed = @"user_dismissed";
NSString *const UAInAppMessageResolutionEventTimedOut = @"timed_out";
NSString *const UAInAppMessageResolutionEventExpired = @"expired";


@implementation UAInAppMessageResolutionEvent

+ (instancetype)legacyReplacedEventWithMessageID:(NSString *)messageID
                                   replacementID:(NSString *)replacementID {

    NSMutableDictionary *resolutionData = [NSMutableDictionary dictionary];
    [resolutionData setValue:UAInAppMessageResolutionEventReplaced forKey:UAInAppMessageResolutionEventTypeKey];
    [resolutionData setValue:replacementID forKey:UAInAppMessageResolutionEventReplacementIDKey];

    NSMutableDictionary *data = [UAInAppMessageEventUtils createDataWithMessageID:messageID
                                                                           source:UAInAppMessageSourceLegacyPush
                                                                        campaigns:nil];

    [data setValue:resolutionData forKey:UAInAppMessageResolutionEventResolutionKey];

    return [[self alloc] initWithData:data];
}

+ (instancetype)legacyDirectOpenEventWithMessageID:(NSString *)messageID {
    NSMutableDictionary *resolutionData = [NSMutableDictionary dictionary];
    [resolutionData setValue:UAInAppMessageResolutionEventDirectOpen forKey:UAInAppMessageResolutionEventTypeKey];

    NSMutableDictionary *data = [UAInAppMessageEventUtils createDataWithMessageID:messageID
                                                                           source:UAInAppMessageSourceLegacyPush
                                                                        campaigns:nil];

    [data setValue:resolutionData forKey:UAInAppMessageResolutionEventResolutionKey];

    return [[self alloc] initWithData:data];
}

+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                      resolution:(UAInAppMessageResolution *)resolution
                     displayTime:(NSTimeInterval)displayTime{

    NSDictionary *resolutionData = [UAInAppMessageResolutionEvent createResolutionDataWithResolution:resolution
                                                                                         displayTime:displayTime];
    NSMutableDictionary *data = [UAInAppMessageEventUtils createDataForMessage:message];
    [data setValue:resolutionData forKey:UAInAppMessageResolutionEventResolutionKey];

    return [[self alloc] initWithData:data];
}

+ (instancetype)eventWithExpiredMessage:(UAInAppMessage *)message
                            expiredDate:(NSDate *)expiredDate {

    NSMutableDictionary *resolutionData = [NSMutableDictionary dictionary];
    [resolutionData setValue:UAInAppMessageResolutionEventExpired forKey:UAInAppMessageResolutionEventTypeKey];

    NSDateFormatter *formatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    [resolutionData setValue:[formatter stringFromDate:expiredDate] forKey:UAInAppMessageResolutionEventExpiryKey];

    NSMutableDictionary *data = [UAInAppMessageEventUtils createDataForMessage:message];
    [data setValue:resolutionData forKey:UAInAppMessageResolutionEventResolutionKey];

    return [[self alloc] initWithData:data];
}

- (instancetype)initWithData:(NSDictionary *)data {
    self = [super init];
    if (self) {
        self.data = data;
    }
    return self;
}

- (NSString *)eventType {
    return UAInAppMessageResolutionEventType;
}

+ (NSDictionary *)createResolutionDataWithResolution:(UAInAppMessageResolution *)resolution
                                         displayTime:(NSTimeInterval)displayTime {

    NSMutableDictionary *resolutionData = [NSMutableDictionary dictionary];
    [resolutionData setValue:[NSString stringWithFormat:@"%.3f", displayTime]
                      forKey:UAInAppMessageResolutionEventDisplayTimeKey];

    switch (resolution.type) {
        case UAInAppMessageResolutionTypeTimedOut:
            [resolutionData setValue:UAInAppMessageResolutionEventTimedOut forKey:UAInAppMessageResolutionEventTypeKey];
            break;

        case UAInAppMessageResolutionTypeButtonClick:
        {
            [resolutionData setValue:UAInAppMessageResolutionEventButtonClick forKey:UAInAppMessageResolutionEventTypeKey];
            [resolutionData setValue:resolution.buttonInfo.identifier forKey:UAInAppMessageResolutionEventButtonIDKey];

            NSString *description = resolution.buttonInfo.label.text;
            if (description.length > MaxButtonDescriptionLength) {
                description = [description substringToIndex:MaxButtonDescriptionLength];
            }

            [resolutionData setValue:description forKey:UAInAppMessageResolutionEventButtonDescriptionKey];
            break;
        }

        case UAInAppMessageResolutionTypeMessageClick:
            [resolutionData setValue:UAInAppMessageResolutionEventMessageClick forKey:UAInAppMessageResolutionEventTypeKey];
            break;

        case UAInAppMessageResolutionTypeUserDismissed:
            [resolutionData setValue:UAInAppMessageResolutionEventUserDismissed forKey:UAInAppMessageResolutionEventTypeKey];
            break;
    }

    return resolutionData;
}

@end

