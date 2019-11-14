#import "UAInAppMessageEventUtils+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAUtils+Internal.h"

NSString *const UAInAppMessageEventIDKey = @"id";
NSString *const UAInAppMessageEventConversionSendIDKey = @"conversion_send_id";
NSString *const UAInAppMessageEventConversionMetadataKey = @"conversion_metadata";
NSString *const UAInAppMessageEventSourceKey = @"source";

NSString *const UAInAppMessageEventMessageIDKey = @"message_id";
NSString *const UAInAppMessageEventCampaignsKey = @"campaigns";

NSString *const UAInAppMessageEventUrbanAirshipSourceValue = @"urban-airship";
NSString *const UAInAppMessageEventAppDefinedSourceValue = @"app-defined";

@implementation UAInAppMessageEventUtils

+ (NSMutableDictionary *)createDataForMessage:(UAInAppMessage *)message {
    return [UAInAppMessageEventUtils createDataWithMessageID:message.identifier
                                                      source:message.source
                                                   campaigns:message.campaigns];
}

+ (NSMutableDictionary *)createDataWithMessageID:(NSString *)messageID
                                          source:(UAInAppMessageSource)source
                                       campaigns:(NSDictionary *)campaigns {

    id identifier = [UAInAppMessageEventUtils createIDMapWithMessageID:messageID
                                                                source:source
                                                             campaigns:campaigns];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data setValue:identifier forKey:UAInAppMessageEventIDKey];
    [data setValue:[UAirship analytics].conversionSendID forKey:UAInAppMessageEventConversionSendIDKey];
    [data setValue:[UAirship analytics].conversionPushMetadata forKey:UAInAppMessageEventConversionMetadataKey];

    if (source == UAInAppMessageSourceAppDefined) {
        [data setValue:UAInAppMessageEventAppDefinedSourceValue forKey:UAInAppMessageEventSourceKey];
    } else {
        [data setValue:UAInAppMessageEventUrbanAirshipSourceValue forKey:UAInAppMessageEventSourceKey];
    }
    return data;
}

+ (id)createIDMapWithMessageID:(NSString *)messageID
                        source:(UAInAppMessageSource)source
                     campaigns:(NSDictionary *)campaigns {

    switch (source) {
        case UAInAppMessageSourceRemoteData: {
            NSMutableDictionary *idMap = [NSMutableDictionary dictionary];
            [idMap setValue:messageID forKey:UAInAppMessageEventMessageIDKey];
            [idMap setValue:campaigns forKey:UAInAppMessageEventCampaignsKey];
            return idMap;
        }

        case UAInAppMessageSourceAppDefined: {
            return @{ UAInAppMessageEventMessageIDKey: messageID };
        }

        case UAInAppMessageSourceLegacyPush:
        default: {
            return messageID;
        }
    }
}


@end

