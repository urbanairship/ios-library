/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

#import "UAEventAPIClient+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAJSONSerialization.h"
#import "UAAnalytics+Internal.h"

NSString * const UAEventAPIClientErrorDomain = @"com.urbanairship.event_api_client";

@implementation UAEventAPIClient

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config {
    return [[UAEventAPIClient alloc] initWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session {
    return [[UAEventAPIClient alloc] initWithConfig:config session:session];
}

-(void)uploadEvents:(NSArray *)events headers:(NSDictionary *)headers completionHandler:(void (^)(NSDictionary * _Nullable responseHeaders, NSError * _Nullable error))completionHandler {
    UARequest *request = [self requestWithEvents:events headers:headers];

    if (uaLogLevel >= UALogLevelTrace) {
        UA_LTRACE(@"Sending analytics events with IDs: %@", [events valueForKey:@"event_id"]);
        UA_LTRACE(@"Sending to server: %@", self.config.analyticsURL);
        UA_LTRACE(@"Sending analytics headers: %@", [request.headers descriptionWithLocale:nil indent:1]);
        UA_LTRACE(@"Sending analytics body: %@", [NSJSONSerialization stringWithObject:events options:NSJSONWritingPrettyPrinted]);
    }

    // Perform the upload
    [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = [self castResponse:response error:&error];

        if (error) {
            return completionHandler(nil, error);
        }

        completionHandler(httpResponse.allHeaderFields, httpResponse.statusCode != 200 ? [self unsuccessfulStatusError] : nil);
    }];
}

- (UARequest *)requestWithEvents:(NSArray *)events headers:(NSDictionary<NSString *, NSString *> *)headers {
    UARequest *request = [UARequest requestWithBuilderBlock:^(UARequestBuilder *builder) {
        builder.URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", self.config.analyticsURL, @"/warp9/"]];
        builder.method = @"POST";

        // Body
        builder.compressBody = YES;
        builder.body = [UAJSONSerialization dataWithJSONObject:events options:0 error:nil];

        // Headers
        [builder addHeaders:headers];
        [builder setValue:@"application/json" forHeader:@"Content-Type"];
        [builder setValue:[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] forHeader:@"X-UA-Sent-At"];
    }];
    
    return request;
}

- (NSError *)unsuccessfulStatusError {
    NSString *msg = [NSString stringWithFormat:@"Event API client encountered an unsuccessful status"];

    NSError *error = [NSError errorWithDomain:UAEventAPIClientErrorDomain
                                         code:UAEventAPIClientErrorUnsuccessfulStatus
                                     userInfo:@{NSLocalizedDescriptionKey:msg}];

    return error;
}

@end
