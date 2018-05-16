/* Copyright 2018 Urban Airship and Contributors */

#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UAConfig.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "NSURLResponse+UAAdditions.h"

#define kUAChannelTagGroupsPath @"/api/channels/tags/"
#define kUANamedUserTagsPath @"/api/named_users/tags/"
#define kUATagGroupsAudienceKey @"audience"
#define kUATagGroupsIosChannelKey @"ios_channel"
#define kUATagGroupsNamedUserIdKey @"named_user_id"
#define kUATagGroupsResponseObjectWarningsKey @"warnings"
#define kUATagGroupsResponseObjectErrorKey @"error"

@interface UATagGroupsAPIClient()
@property (nonatomic,strong) NSString *tagGroupsPath;
@property (nonatomic,strong) NSString *tagGroupsKey;
@end

@implementation UATagGroupsAPIClient

+ (instancetype)channelClientWithConfig:(UAConfig *)config {
    UATagGroupsAPIClient *client = [self channelClientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
    return client;
}

+ (instancetype)channelClientWithConfig:(UAConfig *)config session:(UARequestSession *)session {
    UATagGroupsAPIClient *client = [[self alloc] initWithConfig:config session:session];
    client.tagGroupsPath = kUAChannelTagGroupsPath;
    client.tagGroupsKey = kUATagGroupsIosChannelKey;
    return client;
}

+ (instancetype)namedUserClientWithConfig:(UAConfig *)config {
    UATagGroupsAPIClient *client = [self namedUserClientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
    return client;
}

+ (instancetype)namedUserClientWithConfig:(UAConfig *)config session:(UARequestSession *)session {
    UATagGroupsAPIClient *client = [[self alloc] initWithConfig:config session:session];
    client.tagGroupsPath = kUANamedUserTagsPath;
    client.tagGroupsKey = kUATagGroupsNamedUserIdKey;
    return client;
}

- (void)updateTagGroupsForId:(NSString *)identifier
           tagGroupsMutation:(UATagGroupsMutation *)mutation
           completionHandler:(void (^)(NSUInteger status))completionHandler {

    [self performTagGroupsMutation:mutation
                              path:self.tagGroupsPath
                          audience:@{self.tagGroupsKey : identifier}
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
        builder.body = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
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
                UA_LINFO(@"Tag group request for: %@ completed with warnings: %@", response.URL, responseBody[kUATagGroupsResponseObjectWarningsKey]);
            }

            if (responseBody[kUATagGroupsResponseObjectErrorKey]) {
                UA_LINFO(@"Tag group request for: %@ completed with errors: %@", response.URL, responseBody[kUATagGroupsResponseObjectErrorKey]);
            }
        }

        completionHandler(status);
    }];

}
@end
