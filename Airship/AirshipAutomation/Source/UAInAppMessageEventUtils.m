#import "UAInAppMessageEventUtils+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#elif __has_include("Airship-Swift.h")
#import "Airship-Swift.h"
#else
@import AirshipCore;
#endif
NSString *const UAInAppMessageEventIDKey = @"id";
NSString *const UAInAppMessageEventConversionSendIDKey = @"conversion_send_id";
NSString *const UAInAppMessageEventConversionMetadataKey = @"conversion_metadata";
NSString *const UAInAppMessageEventSourceKey = @"source";

NSString *const UAInAppMessageEventMessageIDKey = @"message_id";
NSString *const UAInAppMessageEventCampaignsKey = @"campaigns";

NSString *const UAInAppMessageEventUrbanAirshipSourceValue = @"urban-airship";
NSString *const UAInAppMessageEventAppDefinedSourceValue = @"app-defined";

@implementation UAInAppMessageEventUtils

+ (NSMutableDictionary *)createDataWithMessageID:(NSString *)messageID
                                          source:(UAInAppMessageSource)source
                                       campaigns:(NSDictionary *)campaigns {


    id<UAAnalyticsProtocol> analytics = UAAnalytics.supplier();
    id identifier = [UAInAppMessageEventUtils createIDMapWithMessageID:messageID
                                                                source:source
                                                             campaigns:campaigns];

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data setValue:identifier forKey:UAInAppMessageEventIDKey];
    [data setValue:analytics.conversionSendID forKey:UAInAppMessageEventConversionSendIDKey];
    [data setValue:analytics.conversionPushMetadata forKey:UAInAppMessageEventConversionMetadataKey];

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

            if (campaigns.count) {
                [idMap setValue:campaigns forKey:UAInAppMessageEventCampaignsKey];
            }
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
