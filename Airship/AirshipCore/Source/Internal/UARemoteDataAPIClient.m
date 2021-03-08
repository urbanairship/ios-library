/* Copyright Airship and Contributors */

#import "UARemoteDataAPIClient+Internal.h"
#import "UAUtils+Internal.h"
#import "UARuntimeConfig.h"
#import "UAirshipVersion.h"
#import "UAirship.h"
#import "NSError+UAAdditions.h"

@interface UARemoteDataResponse()
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *payloads;
@property (nonatomic, copy, nullable) NSString *lastModified;
@end

@implementation UARemoteDataResponse
- (instancetype)initWithStatus:(NSUInteger)status
                      payloads:(NSArray<NSDictionary *> *)payloads
                  lastModified:(NSString *)lastModified {
    self = [super initWithStatus:status];
    if (self) {
        self.payloads = payloads;
        self.lastModified = lastModified;
    }
    return self;
}
@end


@interface UARemoteDataAPIClient()
@property (nonatomic, strong) UARequestSession *session;
@property (nonatomic, strong) UARuntimeConfig *config;
@end

@implementation UARemoteDataAPIClient

NSString * const UARemoteDataAPIClientPath = @"api/remote-data/app";
NSString * const UARemoteDataAPIClientErrorDomain = @"com.urbanairship.remote_data_api_client";

- (UARemoteDataAPIClient *)initWithConfig:(UARuntimeConfig *)config
                                  session:(UARequestSession *)session {
    self = [super init];

    if (self) {
        self.config = config;
        self.session = session;
    }

    return self;
}

+ (UARemoteDataAPIClient *)clientWithConfig:(UARuntimeConfig *)config
                                    session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config
                                session:session];
}

+ (UARemoteDataAPIClient *)clientWithConfig:(UARuntimeConfig *)config {
    return [[self alloc] initWithConfig:config
                                session:[UARequestSession sessionWithConfig:config]];
}


- (UADisposable *)fetchRemoteDataWithLocale:(NSLocale *)locale
                               lastModified:(nullable NSString *)lastModified
                          completionHandler:(UARemoteDataAPIClientCompletionHandler)completionHandler {

    NSURL *URL = [UARemoteDataAPIClient createRemoteDataURLWithURL:self.config.remoteDataAPIURL
                                                            appKey:self.config.appKey
                                                            locale:locale];

    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        builder.URL = URL;
        builder.method = @"GET";
        [builder setValue:lastModified forHeader:@"If-Modified-Since"];
    }];

    UA_LTRACE(@"Request to update remote data: %@", URL);
    return [self.session performHTTPRequest:request
                          completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {

        UA_LTRACE(@"Fetch finished with response: %@ error: %@", response, error);

        if (error) {
            completionHandler(nil, error);
            return;
        }

        if (response.statusCode == 200) {
            NSArray *payloads = [self parseRemoteData:data error:&error];

            if (error) {
                UA_LTRACE(@"Failed to parse remote data with error: %@", error);
                completionHandler(nil, error);
            } else {
                NSString *lastModified = [response.allHeaderFields objectForKey:@"Last-Modified"];
                UARemoteDataResponse *remoteDataResponse = [[UARemoteDataResponse alloc] initWithStatus:response.statusCode
                                                                                               payloads:payloads lastModified:lastModified];

                completionHandler(remoteDataResponse, nil);
            }
        } else {
            UARemoteDataResponse *remoteDataResponse = [[UARemoteDataResponse alloc] initWithStatus:response.statusCode
                                                                                           payloads:nil
                                                                                       lastModified:nil];
            completionHandler(remoteDataResponse, nil);
        }
    }];
}

- (NSArray *)parseRemoteData:(nullable NSData *)data
                       error:(NSError **)error {
    // Missing response body
    if (!data) {
        *error = [NSError airshipParseErrorWithMessage:@"Refresh remote data missing response body."];
        return nil;
    }

    // Parse the response
    NSError *parseError;
    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:NSJSONReadingAllowFragments error:&parseError];


    if (!parseError) {
        return [jsonResponse objectForKey:@"payloads"];
    } else {
        *error = parseError;
        return nil;
    }
}

+ (NSURL *)createRemoteDataURLWithURL:(NSString *)remoteDataAPIURL
                               appKey:(NSString *)appKey
                               locale:(NSLocale *)locale {

    NSURLQueryItem *languageItem = [NSURLQueryItem queryItemWithName:@"language"
                                                               value:[locale objectForKey:NSLocaleLanguageCode]];
    NSURLQueryItem *countryItem = [NSURLQueryItem queryItemWithName:@"country"
                                                              value:[locale objectForKey:NSLocaleCountryCode]];
    NSURLQueryItem *versionItem = [NSURLQueryItem queryItemWithName:@"sdk_version"
                                                              value:[UAirshipVersion get]];

    NSURLComponents *components = [NSURLComponents componentsWithString:remoteDataAPIURL];

    // api/remote-data/app/{appkey}/{platform}?sdk_version={version}&language={language}&country={country}
    components.path = [NSString stringWithFormat:@"/%@/%@/%@", UARemoteDataAPIClientPath, appKey, @"ios"];

    NSMutableArray *queryItems = [NSMutableArray arrayWithObject:versionItem];

    if (languageItem.value != nil && languageItem.value.length != 0) {
        [queryItems addObject:languageItem];
    }

    if (countryItem.value != nil && countryItem.value.length != 0) {
        [queryItems addObject:countryItem];
    }

    components.queryItems = queryItems;

    return [components URL];
}

@end


