/* Copyright Airship and Contributors */

#import "UATagGroupsLookupAPIClient+Internal.h"
#import "UATagGroupsLookupResponse+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
#define kUATagGroupsLookupAPIClientLookupPath @"/api/channel-tags-lookup"
#define kUATagGroupsLookupAPIClientChannelIDKey @"channel_id"
#define kUATagGroupsLookupAPIClientTagGroupsKey @"tag_groups"
#define kUATagGroupsLookupAPIClientDeviceTypeKey @"device_type"
#define kUATagGroupsLookupAPIClientDeviceType @"ios"
#define kUATagGroupsLookupAPIClientIfModifiedSinceKey @"if_modified_since"

@interface UATagGroupsLookupAPIClient()
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UARequestSession *session;
@end

@implementation UATagGroupsLookupAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    self = [super init];
    if (self) {
        self.config = config;
        self.session = session;
    }
    return self;
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config {
    return [[self alloc] initWithConfig:config session:[[UARequestSession alloc] initWithConfig:config]];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session];
}

- (NSURL *)lookupURL {
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", self.config.deviceAPIURL, kUATagGroupsLookupAPIClientLookupPath]];
}

- (NSDictionary *)lookupDictionaryWithChannelID:(NSString *)channelID
                                  requestedTags:(NSDictionary *)requestedTags
                                 cachedResponse:(UATagGroupsLookupResponse *)cachedResponse {

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    [dictionary setValue:channelID forKey:kUATagGroupsLookupAPIClientChannelIDKey];
    [dictionary setValue:requestedTags forKey:kUATagGroupsLookupAPIClientTagGroupsKey];
    [dictionary setValue:kUATagGroupsLookupAPIClientDeviceType forKey:kUATagGroupsLookupAPIClientDeviceTypeKey];

    if (cachedResponse) {
        [dictionary setValue:cachedResponse.lastModifiedTimestamp forKey:kUATagGroupsLookupAPIClientIfModifiedSinceKey];
    }

    return dictionary;
}

- (void)lookupTagGroupsWithChannelID:(NSString *)channelID
                  requestedTagGroups:(UATagGroups *)requestedTagGroups
                      cachedResponse:(UATagGroupsLookupResponse *)cachedResponse
                   completionHandler:(void (^)(UATagGroupsLookupResponse *))completionHandler {
    NSDictionary *payloadDictionary = [self lookupDictionaryWithChannelID:channelID
                                                            requestedTags:[requestedTagGroups toJSON]
                                                           cachedResponse:cachedResponse];

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.url = [self lookupURL];
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;

        builder.body = [UAJSONUtils dataWithObject:payloadDictionary options:NSJSONWritingPrettyPrinted error:nil];

        [builder setValue:@"application/vnd.urbanairship+json; version=3;" header:@"Accept"];
        [builder setValue:@"application/json" header:@"Content-Type"];
    }];

    UA_LTRACE(@"Performing tag group lookup with payload: %@", payloadDictionary);

    [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;

        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSInteger status = httpResponse.statusCode;
        NSDictionary *responseBody;

        if (data) {
            responseBody = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        }

        UATagGroupsLookupResponse *lookupResponse = [UATagGroupsLookupResponse responseWithJSON:responseBody status:status];

        if (status == 200) {
            // We will not receive 304 not modified, so return the cached response if the last modified timestamps match
            if (cachedResponse &&
                lookupResponse.lastModifiedTimestamp &&
                [lookupResponse.lastModifiedTimestamp isEqualToString:cachedResponse.lastModifiedTimestamp]) {
                return completionHandler(cachedResponse);
            }
        }

        completionHandler(lookupResponse);
    }];
}

@end
