/* Copyright Urban Airship and Contributors */

#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UAConfig.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAJSONSerialization+Internal.h"

#define kUAChannelTagGroupsPath @"/api/channels/tags/"
#define kUANamedUserTagsPath @"/api/named_users/tags/"
#define kUATagGroupsAudienceKey @"audience"
#define kUATagGroupsIosChannelKey @"ios_channel"
#define kUATagGroupsNamedUserIdKey @"named_user_id"
#define kUATagGroupsResponseObjectWarningsKey @"warnings"
#define kUATagGroupsResponseObjectErrorKey @"error"

@implementation UATagGroupsAPIClient

+ (instancetype)clientWithConfig:(UAConfig *)config {
    UATagGroupsAPIClient *client = [self clientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
    return client;
}

+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session {
    UATagGroupsAPIClient *client = [[self alloc] initWithConfig:config session:session];
    return client;
}

- (NSString *)keyForType:(UATagGroupsType)type {
    switch (type) {
        case UATagGroupsTypeChannel:
            return kUATagGroupsIosChannelKey;
        case UATagGroupsTypeNamedUser:
            return kUATagGroupsNamedUserIdKey;
    }
}

- (NSString *)pathForType:(UATagGroupsType)type {
    switch (type) {
        case UATagGroupsTypeChannel:
            return kUAChannelTagGroupsPath;
        case UATagGroupsTypeNamedUser:
            return kUANamedUserTagsPath;
    }
}

- (void)updateTagGroupsForId:(NSString *)identifier
           tagGroupsMutation:(UATagGroupsMutation *)mutation
                        type:(UATagGroupsType)type
           completionHandler:(void (^)(NSUInteger status))completionHandler {

    [self performTagGroupsMutation:mutation
                              path:[self pathForType:type]
                          audience:@{[self keyForType:type] : identifier}
                 completionHandler:completionHandler];
}

- (void)performTagGroupsMutation:(UATagGroupsMutation *)mutation
                            path:(NSString *)path
                        audience:(NSDictionary *)audience
               completionHandler:(void (^)(NSUInteger status))completionHandler {

    if (!self.enabled) {
        UA_LDEBUG(@"Disabled");
        return;
    }

    NSMutableDictionary *payload = [[mutation payload] mutableCopy];
    [payload setValue:audience forKey:kUATagGroupsAudienceKey];

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        NSString *urlString = [NSString stringWithFormat:@"%@%@", self.config.deviceAPIURL, path];
        builder.URL = [NSURL URLWithString:urlString];
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;
        builder.body = [UAJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
        [builder setValue:@"application/json" forHeader:@"Content-Type"];
    }];

    UA_LTRACE(@"Updating tag groups with payload: %@", payload);

    [self.session dataTaskWithRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        return [response hasRetriableStatus];
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSInteger status = httpResponse.statusCode;

        if (data) {
            NSDictionary *responseBody = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

            if (responseBody[kUATagGroupsResponseObjectWarningsKey]) {
                UA_LDEBUG(@"Tag group request for: %@ completed with warnings: %@", response.URL, responseBody[kUATagGroupsResponseObjectWarningsKey]);
            }

            if (responseBody[kUATagGroupsResponseObjectErrorKey]) {
                UA_LDEBUG(@"Tag group request for: %@ completed with errors: %@", response.URL, responseBody[kUATagGroupsResponseObjectErrorKey]);
            }
        }

        completionHandler(status);
    }];

}
@end
