/* Copyright Airship and Contributors */

#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UARuntimeConfig.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAJSONSerialization.h"

#define kUAChannelTagGroupsPath @"/api/channels/tags/"
#define kUANamedUserTagsPath @"/api/named_users/tags/"
#define kUATagGroupsAudienceKey @"audience"
#define kUATagGroupsResponseObjectWarningsKey @"warnings"
#define kUATagGroupsResponseObjectErrorKey @"error"

NSString * const UATagGroupsChannelStoreKey = @"ios_channel";
NSString * const UATagGroupsNamedUserStoreKey = @"named_user_id";

@interface UATagGroupsAPIClient()

@property(nonatomic) NSString *storeKey;
@property(nonatomic) NSString *path;

@end

@implementation UATagGroupsAPIClient

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session storeKey:(NSString *)storeKey {
    self = [super initWithConfig:config session:session];
    if (self) {
        self.storeKey = storeKey;
        if ([self.storeKey isEqualToString:UATagGroupsNamedUserStoreKey]) {
            self.path = kUANamedUserTagsPath;
        } else {
            self.path = kUAChannelTagGroupsPath;
        }
    }
    return self;
}

+ (instancetype)channelClientWithConfig:(UARuntimeConfig *)config {
    UATagGroupsAPIClient *client = [self channelClientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
    return client;
}

+ (instancetype)channelClientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session storeKey:UATagGroupsChannelStoreKey];
}

+ (instancetype)namedUserClientWithConfig:(UARuntimeConfig *)config {
    UATagGroupsAPIClient *client = [self namedUserClientWithConfig:config session:[UARequestSession sessionWithConfig:config]];
    return client;
}

+ (instancetype)namedUserClientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session storeKey:UATagGroupsNamedUserStoreKey];
}

- (void)updateTagGroupsForId:(NSString *)identifier
           tagGroupsMutation:(UATagGroupsMutation *)mutation
           completionHandler:(void (^)(NSUInteger status))completionHandler {

    [self performTagGroupsMutation:mutation
                              path:self.path
                          audience:@{self.storeKey : identifier}
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
