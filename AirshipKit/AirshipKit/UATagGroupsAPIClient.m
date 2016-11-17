/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UATagGroupsAPIClient+Internal.h"
#import "UATagGroupsMutation+Internal.h"
#import "UAConfig.h"
#import "NSJSONSerialization+UAAdditions.h"

#define kUAChannelTagGroupsPath @"/api/channels/tags/"
#define kUANamedUserTagsPath @"/api/named_users/tags/"
#define kUATagGroupsAudienceKey @"audience"
#define kUATagGroupsIosChannelKey @"ios_channel"
#define kUATagGroupsNamedUserIdKey @"named_user_id"
#define kUATagGroupsResponseObjectWarningsKey @"warnings"
#define kUATagGroupsResponseObjectErrorKey @"error"

@implementation UATagGroupsAPIClient

+ (instancetype)clientWithConfig:(UAConfig *)config {
    return [[self alloc] initWithConfig:config session:[UARequestSession sessionWithConfig:config]];
}

+ (instancetype)clientWithConfig:(UAConfig *)config session:(UARequestSession *)session {
    return [[self alloc] initWithConfig:config session:session];
}

- (void)updateChannel:(NSString *)channelId
    tagGroupsMutation:(UATagGroupsMutation *)mutation
    completionHandler:(void (^)(NSUInteger status))completionHandler {

    [self performTagGroupsMutation:mutation
                              path:kUAChannelTagGroupsPath
                          audience:@{kUATagGroupsIosChannelKey : channelId}
                 completionHandler:completionHandler];
}

- (void)updateNamedUser:(NSString *)identifier
      tagGroupsMutation:(UATagGroupsMutation *)mutation
      completionHandler:(void (^)(NSUInteger status))completionHandler {

    [self performTagGroupsMutation:mutation
                              path:kUANamedUserTagsPath
                          audience:@{kUATagGroupsNamedUserIdKey : identifier}
                 completionHandler:completionHandler];
}

- (void)performTagGroupsMutation:(UATagGroupsMutation *)mutation
                            path:(NSString *)path
                        audience:(NSDictionary *)audience
               completionHandler:(void (^)(NSUInteger status))completionHandler {


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
        NSHTTPURLResponse *httpResponse = nil;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *) response;
        }

        NSInteger status = httpResponse.statusCode;
        return (BOOL)((status >= 500 && status <= 599));
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
