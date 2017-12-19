/* Copyright 2017 Urban Airship and Contributors */

#import "UALegacyInAppResolutionEvent+Internal.h"
#import "UALegacyInAppMessage.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAEvent+Internal.h"
#import "UAUtils.h"

@implementation UALegacyInAppResolutionEvent

- (instancetype) initWithMessageID:(NSString *)messageID resolution:(NSDictionary *)resolution {
    self = [super init];
    if (self) {
        NSMutableDictionary *data = [NSMutableDictionary dictionary];
        [data setValue:messageID forKey:@"id"];
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

+ (instancetype)replacedResolutionWithMessageID:(NSString *)messageID
                                  replacement:(NSString *)replacementID {

    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"replaced" forKey:@"type"];
    [resolution setValue:replacementID forKey:@"replacement_id"];

    return [[self alloc] initWithMessageID:messageID resolution:resolution];
}

+ (instancetype)directOpenResolutionWithMessageID:(NSString *)messageID {
    NSMutableDictionary *resolution = [NSMutableDictionary dictionary];
    [resolution setValue:@"direct_open" forKey:@"type"];

    return [[self alloc] initWithMessageID:messageID resolution:resolution];
}

@end
