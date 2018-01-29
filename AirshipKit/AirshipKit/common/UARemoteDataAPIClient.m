/* Copyright 2018 Urban Airship and Contributors */

#import "UARemoteDataAPIClient+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAUtils.h"
#import "UAConfig+Internal.h"

@interface UARemoteDataAPIClient()

@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UARemoteDataAPIClient

NSString * const kUALastRemoteDataModifiedTime = @"UALastRemoteDataModifiedTime";

- (UARemoteDataAPIClient *)initWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super initWithConfig:config session:[UARequestSession sessionWithConfig:config]];
    
    if (self) {
        self.dataStore = dataStore;
    }
    
    return self;
}

+ (UARemoteDataAPIClient *)clientWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[[self class] alloc] initWithConfig:config dataStore:dataStore];
}

- (UADisposable *)fetchRemoteData:(UARemoteDataRefreshSuccessBlock)successBlock onFailure:(UARemoteDataRefreshFailureBlock)failureBlock {
    UA_LDEBUG(@"started");
    UARequest *refreshRequest = [self requestToRefreshRemoteData];
    
    __block UARemoteDataRefreshSuccessBlock refreshRemoteDataSuccessBlock = successBlock;
    __block UARemoteDataRefreshFailureBlock refreshRemoteDataFailureBlock = failureBlock;
    
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        UA_LDEBUG(@"disposed");
        refreshRemoteDataSuccessBlock = nil;
        refreshRemoteDataFailureBlock = nil;
    }];
    

    [self.session dataTaskWithRequest:refreshRequest retryWhere:^BOOL(NSData * _Nullable data, NSURLResponse * _Nullable response) {
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
            if (httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599) {
                return YES;
            }
        }
        
        return NO;
    } completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
            if (refreshRemoteDataFailureBlock) {
                refreshRemoteDataFailureBlock();
            }
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        
        // Failure
        if (httpResponse.statusCode != 200  && httpResponse.statusCode != 304) {
            [UAUtils logFailedRequest:refreshRequest withMessage:@"Refresh remote data failed" withError:error withResponse:httpResponse];
            if (refreshRemoteDataFailureBlock) {
                refreshRemoteDataFailureBlock();
            }
            return;
        }
        
        // 304, no changes
        if (httpResponse.statusCode == 304) {
            if (refreshRemoteDataSuccessBlock) {
                refreshRemoteDataSuccessBlock(httpResponse.statusCode, nil);
            }
            return;
        }
        
        // 200, success
        
        // Missing response body
        if (!data) {
            UA_LTRACE(@"Refresh remote data missing response body.");
            if (refreshRemoteDataFailureBlock) {
                refreshRemoteDataFailureBlock();
            }
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
            if (refreshRemoteDataFailureBlock) {
                refreshRemoteDataFailureBlock();
            }
            return;
        }

        UA_LTRACE(@"Retrieved remote data with status: %ld jsonResponse: %@", (unsigned long)httpResponse.statusCode, jsonResponse);
        
        NSArray *remoteData = [jsonResponse objectForKey:@"payloads"];
        
        [self.dataStore setValue:lastModified forKey:kUALastRemoteDataModifiedTime];
        
        if (refreshRemoteDataSuccessBlock) {
            refreshRemoteDataSuccessBlock(httpResponse.statusCode, remoteData);
        }
    }];
    
    return disposable;

}

- (UARequest *)requestToRefreshRemoteData {
    
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder * _Nonnull builder) {
        
        NSString *urlString = [NSString stringWithFormat: @"%@%@", self.config.remoteDataAPIURL, [NSString stringWithFormat: @"/api/remote-data/app/%@/%@", self.config.appKey, @"ios"]];
        
        NSURL *requestUrl = [NSURL URLWithString: urlString];
        
        builder.URL = requestUrl;
        builder.method = @"GET";
        
        NSString *lastModified = [self.dataStore stringForKey:kUALastRemoteDataModifiedTime];
        
        if (lastModified) {
            [builder setValue:lastModified forHeader:@"If-Modified-Since"];
        }
        
        UA_LTRACE(@"Request to refresh remote data: %@", urlString);
    }];
    
    return request;
}

- (void)clearLastModifiedTime {
    [self.dataStore removeObjectForKey:kUALastRemoteDataModifiedTime];
}

@end
