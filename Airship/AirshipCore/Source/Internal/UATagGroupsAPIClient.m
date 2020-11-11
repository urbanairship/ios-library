/* Copyright Airship and Contributors */

#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UARuntimeConfig.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAJSONSerialization.h"

#define kUATagGroupsAudienceKey @"audience"
#define kUATagGroupsResponseObjectWarningsKey @"warnings"
#define kUATagGroupsResponseObjectErrorKey @"error"

NSString * const UAChannelTagGroupsPath = @"/api/channels/tags/";
NSString * const UANamedUserTagsPath = @"/api/named_users/tags/";
NSString * const UATagGroupsChannelTypeKey = @"ios_channel";
NSString * const UATagGroupsNamedUserTypeKey = @"named_user_id";

NSString * const UATagGroupsAPIClientErrorDomain = @"com.urbanairship.tag_groups_api_client";

@interface UATagGroupsAPIClient()

@property(nonatomic) NSString *typeKey;
@property(nonatomic) NSString *path;

@end

@implementation UATagGroupsAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session typeKey:(NSString *)typeKey path:(NSString *)path {
    self = [super initWithConfig:config session:session queue:nil];
    if (self) {
        self.typeKey = typeKey;
        self.path = path;
    }
    return self;
}

+ (instancetype)channelClientWithConfig:(UARuntimeConfig *)config {
    return [self channelClientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

+ (instancetype)channelClientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    UATagGroupsAPIClient *client = [[self alloc] initWithConfig:config session:session typeKey:UATagGroupsChannelTypeKey path:UAChannelTagGroupsPath];
    return client;
}

+ (instancetype)namedUserClientWithConfig:(UARuntimeConfig *)config {
    return [self namedUserClientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

+ (instancetype)namedUserClientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    UATagGroupsAPIClient *client = [[self alloc] initWithConfig:config session:session typeKey:UATagGroupsNamedUserTypeKey path:UANamedUserTagsPath];
    return client;
}

- (void)updateTagGroupsForId:(NSString *)identifier
           tagGroupsMutation:(UATagGroupsMutation *)mutation
           completionHandler:(void (^)(NSError * _Nullable))completionHandler {

    [self performTagGroupsMutation:mutation
                              path:self.path
                          audience:@{self.typeKey : identifier}
                 completionHandler:completionHandler];
}

- (void)performTagGroupsMutation:(UATagGroupsMutation *)mutation
                            path:(NSString *)path
                        audience:(NSDictionary *)audience
               completionHandler:(void (^)(NSError * _Nullable))completionHandler {

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

    [self performRequest:request retryWhere:^BOOL(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response) {
        return [response hasRetriableStatus];
    } completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            return completionHandler(error);
        }

        NSInteger status = response.statusCode;

        if (data) {
            NSDictionary *responseBody = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

            if (responseBody[kUATagGroupsResponseObjectWarningsKey]) {
                UA_LDEBUG(@"Tag group request for: %@ completed with warnings: %@", response.URL, responseBody[kUATagGroupsResponseObjectWarningsKey]);
            }

            if (responseBody[kUATagGroupsResponseObjectErrorKey]) {
                UA_LDEBUG(@"Tag group request for: %@ completed with errors: %@", response.URL, responseBody[kUATagGroupsResponseObjectErrorKey]);
            }
        }

        if (!(status >= 200 && status <= 299)) {
            if (status == 400 || status == 403) {
                return completionHandler([self unrecoverableStatusError]);
            }

            return completionHandler([self unsuccessfulStatusError]);
        }

        completionHandler(nil);
    }];
}

- (NSError *)unsuccessfulStatusError {
    NSString *msg = [NSString stringWithFormat:@"Tag groups client encountered an unsuccessful status"];

    NSError *error = [NSError errorWithDomain:UATagGroupsAPIClientErrorDomain
                                         code:UATagGroupsAPIClientErrorUnsuccessfulStatus
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
}

- (NSError *)unrecoverableStatusError {
    NSString *msg = [NSString stringWithFormat:@"Tag groups client encountered an unrecoverable status"];

    NSError *error = [NSError errorWithDomain:UATagGroupsAPIClientErrorDomain
                                         code:UATagGroupsAPIClientErrorUnrecoverableStatus
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
}

@end

