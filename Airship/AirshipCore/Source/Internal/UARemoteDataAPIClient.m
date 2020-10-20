/* Copyright Airship and Contributors */

#import "UARemoteDataAPIClient+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAUtils+Internal.h"
#import "UARuntimeConfig.h"
#import "NSURLResponse+UAAdditions.h"
#import "UAirshipVersion.h"
#import "UAirship.h"

@interface UARemoteDataAPIClient()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UALocaleManager *localeManager;
@end

@implementation UARemoteDataAPIClient

NSString * const kRemoteDataPath = @"api/remote-data/app";
NSString * const kUALastRemoteDataModifiedTime = @"UALastRemoteDataModifiedTime";

NSString * const UARemoteDataAPIClientErrorDomain = @"com.urbanairship.remote_data_api_client";

- (UARemoteDataAPIClient *)initWithConfig:(UARuntimeConfig *)config
                                dataStore:(UAPreferenceDataStore *)dataStore
                                  session:(UARequestSession *)session
                            localeManager:(UALocaleManager *)localeManager {
    self = [super initWithConfig:config session:session];
    
    if (self) {
        self.dataStore = dataStore;
        self.localeManager = localeManager;
    }
    
    return self;
}

+ (UARemoteDataAPIClient *)clientWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore localeManager:(UALocaleManager *)localeManager {
    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                session:[UARequestSession sessionWithConfig:config]
                          localeManager:localeManager];
}

+ (UARemoteDataAPIClient *)clientWithConfig:(UARuntimeConfig *)config
                                  dataStore:(UAPreferenceDataStore *)dataStore
                                    session:(UARequestSession *)session
                              localeManager:(UALocaleManager *)localeManager {
    return [[self alloc] initWithConfig:config
                              dataStore:dataStore
                                session:session
                          localeManager:localeManager];
}

- (UADisposable *)fetchRemoteData:(void (^)(NSArray<NSDictionary *> * _Nullable remoteData, NSError * _Nullable error))completionHandler {
    UARequest *refreshRequest = [self requestToRefreshRemoteData];

    UA_LTRACE(@"Request to refresh remote data: %@", refreshRequest.URL);

    __block void (^refreshCompletionHandler)(NSArray<NSDictionary *> * _Nullable remoteData, NSError * _Nullable error) = completionHandler;
    
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        UA_LTRACE(@"Remote data refresh block disposed");
        refreshCompletionHandler = ^(NSArray<NSDictionary *> * _Nullable remoteData, NSError * _Nullable error){};
    }];

    [self.session dataTaskWithRequest:refreshRequest retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        return [response hasRetriableStatus];
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            refreshCompletionHandler(nil, error);
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        
        // Failure
        if (httpResponse.statusCode != 200  && httpResponse.statusCode != 304) {
            [UAUtils logFailedRequest:refreshRequest withMessage:@"Refresh remote data failed" withError:error withResponse:httpResponse];
            refreshCompletionHandler(nil, [self unsuccessfulStatusError]);
            return;
        }
        
        // 304, no changes
        if (httpResponse.statusCode == 304) {
            refreshCompletionHandler(nil, nil);
            return;
        }
        
        // 200, success
        
        // Missing response body
        if (!data) {
            UA_LTRACE(@"Refresh remote data missing response body.");
            refreshCompletionHandler(nil, [self invalidResponseError]);
            return;
        }
        
        // Success
        NSDictionary *headers = httpResponse.allHeaderFields;
        NSString *lastModified = [headers objectForKey:@"Last-Modified"];
        
        // Parse the response
        NSError *parseError;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&parseError];
        
        if (parseError) {
            UA_LERR(@"Unable to parse remote data body: %@ Error: %@", data, parseError);
            refreshCompletionHandler(nil, parseError);
            return;
        }

        UA_LTRACE(@"Retrieved remote data with status: %ld jsonResponse: %@", (unsigned long)httpResponse.statusCode, jsonResponse);
        
        NSArray *remoteData = [jsonResponse objectForKey:@"payloads"];
        
        [self.dataStore setValue:lastModified forKey:kUALastRemoteDataModifiedTime];

        refreshCompletionHandler(remoteData, nil);
    }];
    
    return disposable;
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

- (UARequest *)requestToRefreshRemoteData {
    UA_WEAKIFY(self)
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        UA_STRONGIFY(self)

        builder.URL = [self createRemoteDataURL:[self.localeManager currentLocale]];
        builder.method = @"GET";
        
        NSString *lastModified = [self.dataStore stringForKey:kUALastRemoteDataModifiedTime];
        
        if (lastModified) {
            [builder setValue:lastModified forHeader:@"If-Modified-Since"];
        }
    }];
    
    return request;
}

- (NSURL *)createRemoteDataURL:(NSLocale *)locale {
    NSURLQueryItem *languageItem = [NSURLQueryItem queryItemWithName:@"language"
                                                               value:[locale objectForKey:NSLocaleLanguageCode]];
    NSURLQueryItem *countryItem = [NSURLQueryItem queryItemWithName:@"country"
                                                              value:[locale objectForKey:NSLocaleCountryCode]];
    NSURLQueryItem *versionItem = [NSURLQueryItem queryItemWithName:@"sdk_version"
                                                              value:[UAirshipVersion get]];

    NSURLComponents *components = [NSURLComponents componentsWithString:self.config.remoteDataAPIURL];

    // api/remote-data/app/{appkey}/{platform}?sdk_version={version}&language={language}&country={country}
    components.path = [NSString stringWithFormat:@"/%@/%@/%@", kRemoteDataPath, self.config.appKey, @"ios"];

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

- (void)clearLastModifiedTime {
    [self.dataStore removeObjectForKey:kUALastRemoteDataModifiedTime];
}

@end
