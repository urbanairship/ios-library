/* Copyright Airship and Contributors */

#import "UAAttributeAPIClient+Internal.h"
#import "UARuntimeConfig.h"
#import "UAUtils+Internal.h"
#import "UAirship.h"
#import "UAAnalytics+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAJSONSerialization.h"
#import "UAAttributePendingMutations.h"
#import "NSString+UAURLEncoding.h"

NSString *const UAChannelsAPIPath = @"/api/channels/";
NSString *const UAAttributePlatformSpecifier = @"/attributes?platform=";
NSString *const UAAttributePlatform = @"ios";

NSString *const UANamedUserAPIPath = @"/api/named_users/";
NSString *const UAAttributeSpecifier = @"/attributes";

@interface UAAttributeAPIClient()
@property (nonatomic, copy) NSURL *(^URLFactoryBlock)(UARuntimeConfig *, NSString *);
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UARequestSession *session;
@end

@implementation UAAttributeAPIClient


- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       session:(UARequestSession *)session
               URLFactoryBlock:(NSURL *(^)(UARuntimeConfig *, NSString *))URLFactoryBlock {
    self = [super init];
    if (self) {
        self.config = config;
        self.session = session;
        self.URLFactoryBlock = URLFactoryBlock;
    }
    return self;
}

+ (instancetype)channelClientWithConfig:(UARuntimeConfig *)config {
    NSURL *(^URLFactoryBlock)(UARuntimeConfig *, NSString *) = ^NSURL *(UARuntimeConfig *config, NSString *identifier) {
        NSString *attributeEndpoint = [NSString stringWithFormat:@"%@%@%@%@%@", config.deviceAPIURL, UAChannelsAPIPath, identifier, UAAttributePlatformSpecifier, UAAttributePlatform];
        return [NSURL URLWithString:attributeEndpoint];

    };

    return [UAAttributeAPIClient clientWithConfig:config
                                          session:[UARequestSession sessionWithConfig:config]
                                  URLFactoryBlock:URLFactoryBlock];
}

+ (instancetype)namedUserClientWithConfig:(UARuntimeConfig *)config {
    NSURL *(^URLFactoryBlock)(UARuntimeConfig *, NSString *) = ^NSURL *(UARuntimeConfig *config, NSString *identifier) {
        NSString *attributeEndpoint =  [NSString stringWithFormat:@"%@%@%@%@", config.deviceAPIURL, UANamedUserAPIPath, [identifier urlEncodedString], UAAttributeSpecifier];
        return [NSURL URLWithString:attributeEndpoint];
    };

    return [self clientWithConfig:config
                          session:[UARequestSession sessionWithConfig:config]
                  URLFactoryBlock:URLFactoryBlock];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config
                         session:(UARequestSession *)session
                 URLFactoryBlock:(NSURL *(^)(UARuntimeConfig *, NSString *))URLFactoryBlock {
    return [[self alloc] initWithConfig:config session:session URLFactoryBlock:URLFactoryBlock];
}

- (UADisposable *)updateWithIdentifier:(NSString *)identifier
                    attributeMutations:(UAAttributePendingMutations *)mutations
                     completionHandler:(void (^)(UAHTTPResponse *response, NSError *error))completionHandler {

    UA_LTRACE(@"Updating attributes for identifier: %@ with attribute payload: %@.", identifier, mutations);

    NSData *payloadData = [UAJSONSerialization dataWithJSONObject:mutations.payload
                                                          options:0
                                                            error:nil];

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.URL = self.URLFactoryBlock(self.config, identifier);
        builder.method = @"POST";
        builder.username = self.config.appKey;
        builder.password = self.config.appSecret;
        builder.body = payloadData;
        [builder setValue:@"application/vnd.urbanairship+json; version=3;" forHeader:@"Accept"];
        [builder setValue:@"application/json" forHeader:@"Content-Type"];
    }];
    
    return [self.session performHTTPRequest:request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        UA_LTRACE(@"Update finished with response: %@ error: %@", response, error);

        if (error) {
            completionHandler(nil, error);
        } else {
            completionHandler([[UAHTTPResponse alloc] initWithStatus:response.statusCode], nil);
        }
    }];
}

@end

