/* Copyright Airship and Contributors */

#import "UAInAppMessageResolutionEvent+Internal.h"
#import "UAInAppMessageEventUtils+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

NSString *const UAInAppMessageResolutionEventType = @"in_app_resolution";

// Keys
NSString *const UAInAppMessageResolutionEventTypeKey = @"type";
NSString *const UAInAppMessageResolutionEventResolutionKey = @"resolution";
NSString *const UAInAppMessageResolutionEventDisplayTimeKey = @"display_time";
NSString *const UAInAppMessageResolutionEventButtonIDKey = @"button_id";
NSString *const UAInAppMessageResolutionEventButtonDescriptionKey = @"button_description";
NSString *const UAInAppMessageResolutionEventReplacementIDKey = @"replacement_id";
NSString *const UAInAppMessageResolutionEventLocaleKey = @"locale";

// Resolution types
NSString *const UAInAppMessageResolutionEventReplaced = @"replaced";
NSString *const UAInAppMessageResolutionEventDirectOpen = @"direct_open";
NSString *const UAInAppMessageResolutionEventMessageClick = @"message_click";
NSString *const UAInAppMessageResolutionEventButtonClick = @"button_click";
NSString *const UAInAppMessageResolutionEventUserDismissed = @"user_dismissed";
NSString *const UAInAppMessageResolutionEventTimedOut = @"timed_out";

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

+ (instancetype)eventWithMessageID:(NSString *)messageID
                            source:(UAInAppMessageSource)source
                        resolution:(UAInAppMessageResolution *)resolution
                       displayTime:(NSTimeInterval)displayTime
                         campaigns:(nullable NSDictionary *)campaigns {

    NSDictionary *resolutionData = [UAInAppMessageResolutionEvent createResolutionDataWithResolution:resolution
                                                                                         displayTime:displayTime];
    NSMutableDictionary *data = [UAInAppMessageEventUtils createDataWithMessageID:messageID source:source campaigns:campaigns];
    [data setValue:resolutionData forKey:UAInAppMessageResolutionEventResolutionKey];
    return [[self alloc] initWithData:data];
}

- (instancetype)initWithData:(NSDictionary *)data {
    self = [super init];
    if (self) {
        self.eventData = data;
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

- (NSDictionary *)data {
    return self.eventData;
}

@end

