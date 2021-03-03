/* Copyright Airship and Contributors */

#import "UARemoteDataAPIClient+Internal.h"
#import "UAUtils+Internal.h"
#import "UARuntimeConfig.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAirshipVersion.h"
#import "UAirship.h"

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

        if (error) {
            UA_LTRACE(@"Update finished with error: %@", error);
            completionHandler(nil, nil, error);
            return;
        }

        UA_LTRACE(@"Update of %@ finished with status: %ld", response.URL, response.statusCode);

        // 304, no changes
        if (response.statusCode == 304) {
            completionHandler(nil, nil, nil);
            return;
        }

        // Failure
        if (response.statusCode != 200) {
            completionHandler(nil, nil, [self unsuccessfulStatusError]);
            return;
        }

        NSArray *payloads = [self parseRemoteData:data error:&error];

        if (error) {
            UA_LTRACE(@"Failed to parse remote data with status: %ld error: %@", (unsigned long)response.statusCode, error);
            completionHandler(nil, nil, error);
        } else {
            NSString *lastModified = [response.allHeaderFields objectForKey:@"Last-Modified"];
            completionHandler(payloads, lastModified, nil);
        }
    }];
}

- (NSArray *)parseRemoteData:(nullable NSData *)data
                       error:(NSError **)error {
    // Missing response body
    if (!data) {
        UA_LTRACE(@"Refresh remote data missing response body.");
        *error = [self invalidResponseError];
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

- (NSError *)unsuccessfulStatusError {
    NSString *msg = [NSString stringWithFormat:@"Remote data client encountered an unsuccessful status"];

    NSError *error = [NSError errorWithDomain:UARemoteDataAPIClientErrorDomain
                                         code:UARemoteDataAPIClientErrorUnsuccessfulStatus
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
}

- (NSError *)invalidResponseError {
    NSString *msg = [NSString stringWithFormat:@"Remote data client encountered an invalid server response"];

    NSError *error = [NSError errorWithDomain:UARemoteDataAPIClientErrorDomain
                                         code:UARemoteDataAPIClientErrorInvalidResponse
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
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


