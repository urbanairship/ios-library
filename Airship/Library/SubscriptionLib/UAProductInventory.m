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

#import "UAProductInventory.h"
#import "UASubscription.h"
#import "UASubscriptionProduct.h"
#import "UAirship.h"
#import "UAUser.h"
#import "UAUtils.h"
#import "UA_ASIHTTPRequest.h"
#import "UA_SBJSON.h"
#import "UASubscriptionManager.h"
#import "UASubscriptionInventory.h"
#import "UASubscriptionObserver.h"

static int compareSubscription(id subscriptionKey, id otherSubscriptionKey, void *context);
static int compareProduct(id productID, id otherProductID, void *context);

@implementation UAProductInventory

@synthesize productDict;
@synthesize hasLoaded;
@synthesize productIDArray;

- (void)dealloc {
    RELEASE_SAFELY(productDict);
    RELEASE_SAFELY(productIDArray);
    [super dealloc];
}

- (id)init {
    if (!(self = [super init]))
        return nil;

    productDict = [[NSMutableDictionary alloc] init];
    productIDArray = [[NSMutableArray alloc] init];
    hasLoaded = NO;
    return self;
}

- (NSArray *)productsForSubscription:(NSString *)subscriptionKey {
    return [[productDict allValues] filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"subscriptionKey like[c] %@", subscriptionKey]];
}

#pragma mark -
#pragma mark Load Inventory

- (void)loadInventory {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/user/%@/available_subscriptions/",
                           [UAirship shared].server,
                           [UAUser defaultUser].username];

    UA_ASIHTTPRequest *request = [UAUtils userRequestWithURL:[NSURL URLWithString:urlString]
                                                   method:@"GET"
                                                 delegate:self
                                                   finish:@selector(inventoryLoaded:)];
    [request startAsynchronous];
}

- (void)inventoryLoaded:(UA_ASIHTTPRequest *)request {
    UA_SBJsonParser *parser = [UA_SBJsonParser new];
    NSArray *optionsArray = [parser objectWithString:request.responseString];
    [parser release];

    [self loadWithArray:optionsArray];

    UALOG(@"Available products loaded: %d\n%@\n",
          request.responseStatusCode, optionsArray);

    if ([productIDArray count] > 0) {
        SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                              initWithProductIdentifiers:[NSSet setWithArray:productIDArray]];
        productsRequest.delegate = self;
        [productsRequest start];
    }
}

- (void)loadWithArray:(NSArray *)invArray {
    [productIDArray removeAllObjects];
    [productDict removeAllObjects];

    for (NSDictionary *productJSON in invArray) {
        UASubscriptionProduct *product = [[UASubscriptionProduct alloc] initWithDict:productJSON];
        [self addProduct:product];
        [product release];
    }

    // sort
    [productIDArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
}

#pragma mark HTTP Request Failure Handler

- (void)requestWentWrong:(UA_ASIHTTPRequest*)request {
    [UAUtils requestWentWrong:request];
}

#pragma mark -
#pragma mark SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    UASubscriptionProduct *uaProduct = nil;
    for(SKProduct *skitem in response.products) {
        uaProduct = [self.productDict objectForKey:skitem.productIdentifier];
        if(uaProduct != nil) {
            uaProduct.title = [skitem localizedTitle];
            uaProduct.productDescription = [skitem localizedDescription];
            NSString* localizedPrice = [UAProductInventory localizedPrice:skitem];
            uaProduct.price = localizedPrice;
            uaProduct.priceNumber = skitem.price;
        }
    }

    for(NSString *invalid in response.invalidProductIdentifiers) {
        UALOG(@"INVALID PRODUCT ID: %@", invalid);
        [self removeProduct:invalid];
    }

    // Wait until inventory is loaded to add an observer
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[UASubscriptionManager shared].transactionObserver];
    RELEASE_SAFELY(request);
    hasLoaded = YES;

    [[UASubscriptionManager shared].inventory productInventoryUpdated];
    //[self notifyObservers:@selector(productInventoryUpdated)];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    UALOG(@"Connection to Apple server ERROR: NSError query result: %@", error);
    RELEASE_SAFELY(request);
}

#pragma mark -

- (void)addProduct:(UASubscriptionProduct *)product {
    [productDict setObject:product
                    forKey:product.productIdentifier];
    [productIDArray addObject:product.productIdentifier];
}

- (void)removeProduct:(NSString*)productId {
    [productDict removeObjectForKey:productId];
    [productIDArray removeObject:productId];
}

- (BOOL)containsProduct:(NSString *)productID {
    return [productIDArray containsObject:productID];
}

- (UASubscriptionProduct *)productForKey:(NSString *)productKey {
    return [productDict objectForKey:productKey];
}

+(NSString*)localizedPrice:(SKProduct*)product {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior: NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle: NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale: product.priceLocale];
    NSString *formattedString = [numberFormatter stringFromNumber: product.price];
    [numberFormatter release];
    return formattedString;
}

@end