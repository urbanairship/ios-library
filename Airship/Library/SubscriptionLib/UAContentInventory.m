/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UAContentInventory.h"
#import "UASubscriptionContent.h"
#import "UAirship.h"
#import "UAUser.h"
#import "UA_ASIHTTPRequest.h"
#import "UAUtils.h"
#import "UA_SBJSON.h"
#import "UASubscriptionManager.h"
#import "UASubscriptionInventory.h"


@implementation UAContentInventory

@synthesize contentArray;

- (void)dealloc {
    [contentArray release];
    [super dealloc];
}

- (id)init {
    if (!(self = [super init]))
        return nil;

    contentArray = [[NSMutableArray alloc] init];
    return self;
}

- (NSArray *)contentsForSubscription:(NSString *)subscriptionKey {
    return [contentArray filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"subscriptionKey like[c] %@", subscriptionKey]];
}

#pragma mark -
#pragma mark Load Inventory

- (void)loadInventory {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/user/%@/subscription_content/",
                           [[UAirship shared] server],
                           [UAUser defaultUser].username];

    UA_ASIHTTPRequest *request = [UAUtils userRequestWithURL:[NSURL URLWithString:urlString]
                                                   method:@"GET"
                                                 delegate:self
                                                   finish:@selector(inventoryLoaded:)
                                                        fail:@selector(inventoryRequestFailed:)];

    [request startAsynchronous];
}

- (void)inventoryLoaded:(UA_ASIHTTPRequest *)request {
    
    // if the request failed
    if (request.responseStatusCode != 200) {
        UALOG(@"retrieving user subscription content failed, response: %d-%@",
              request.responseStatusCode, request.responseString);
        
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        [userInfo setObject:[request.url absoluteString] forKey:NSErrorFailingURLStringKey];
        [userInfo setObject:UASubscriptionContentInventoryFailure forKey:NSLocalizedDescriptionKey];
        
        NSError *error = [NSError errorWithDomain:@"com.urbanairship" code:request.responseStatusCode userInfo:userInfo];
        [[UASubscriptionManager shared] inventoryUpdateFailedWithError:error];
        
        return;
    }

    // Contents successfully loaded
    UALOG(@"User contents loaded: %d\n%@\n", request.responseStatusCode,
          request.responseString);

    UA_SBJsonParser *parser = [UA_SBJsonParser new];
    NSArray *contents = [parser objectWithString:request.responseString];
    [parser release];
    [self loadWithArray:contents];

    [[UASubscriptionManager shared].inventory contentInventoryUpdated];

}

- (void)inventoryRequestFailed:(UA_ASIHTTPRequest *)request {
    
    UALOG(@"Content inventory request failed.");
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:[request.url absoluteString] forKey:NSErrorFailingURLStringKey];
    [userInfo setObject:UASubscriptionContentInventoryFailure forKey:NSLocalizedDescriptionKey];
    
    NSError *error = [NSError errorWithDomain:@"com.urbanairship" code:request.responseStatusCode userInfo:userInfo];
    [[UASubscriptionManager shared] inventoryUpdateFailedWithError:error];
}

- (void)loadWithArray:(NSArray *)array {
    [contentArray removeAllObjects];
    
    for (NSDictionary *contentDict in array) {
        UASubscriptionContent *content = [[UASubscriptionContent alloc] initWithDict:contentDict];
        [[UASubscriptionManager shared].inventory checkDownloading:content];
        [contentArray addObject:content];
        [content release];
    }
    
    [contentArray sortUsingSelector:@selector(compare:)];
}

#pragma mark -
#pragma mark HTTP Request Failure Handler

- (void)requestWentWrong:(UA_ASIHTTPRequest*)request {
    [UAUtils requestWentWrong:request];
}

@end
