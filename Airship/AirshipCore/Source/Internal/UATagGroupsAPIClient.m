/* Copyright Airship and Contributors */

#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UARuntimeConfig.h"
#import "NSJSONSerialization+UAAdditions.h"
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

@property (nonatomic) NSString *typeKey;
@property (nonatomic) NSString *path;
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UARequestSession *session;

@end

@implementation UATagGroupsAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session typeKey:(NSString *)typeKey path:(NSString *)path {
    self = [super init];
    if (self) {
        self.config = config;
        self.session = session;
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

- (UADisposable *)updateTagGroupsForId:(NSString *)identifier
           tagGroupsMutation:(UATagGroupsMutation *)mutation
                     completionHandler:(void (^)(UAHTTPResponse *, NSError *))completionHandler {

    return [self performTagGroupsMutation:mutation
                              path:self.path
                          audience:@{self.typeKey : identifier}
                 completionHandler:completionHandler];
}

- (UADisposable *)performTagGroupsMutation:(UATagGroupsMutation *)mutation
                            path:(NSString *)path
                        audience:(NSDictionary *)audience
               completionHandler:(void (^)(UAHTTPResponse *, NSError *))completionHandler {

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

    return [self.session performHTTPRequest:request completionHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        UA_LTRACE(@"Update finished with response: %@ error: %@", response, error);

        if (error) {
            completionHandler(nil, error);
        } else {

            if (data) {
                NSDictionary *responseBody = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

                if (responseBody[kUATagGroupsResponseObjectWarningsKey]) {
                    UA_LDEBUG(@"Tag group request for: %@ completed with warnings: %@", response.URL, responseBody[kUATagGroupsResponseObjectWarningsKey]);
                }

                if (responseBody[kUATagGroupsResponseObjectErrorKey]) {
                    UA_LDEBUG(@"Tag group request for: %@ completed with errors: %@", response.URL, responseBody[kUATagGroupsResponseObjectErrorKey]);
                }
            }

            completionHandler([[UAHTTPResponse alloc] initWithStatus:response.statusCode], nil);
        }
    }];
}

@end

