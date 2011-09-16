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

#import "UASubscriptionInventory.h"

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import "UA_SBJSON.h"
#import "UA_ASIHTTPRequest.h"

#import "UAGlobal.h"
#import "UAirship.h"
#import "UAUtils.h"

#import "UAUser.h"
#import "UASubscription.h"
#import "UASubscriptionProduct.h"
#import "UASubscriptionContent.h"
#import "UAProductInventory.h"
#import "UAContentInventory.h"
#import "UASubscriptionManager.h"
#import "UASubscriptionDownloadManager.h"

@interface UASubscriptionInventory()
- (void)createSubscription;
- (void)createUserSubscription;
- (void)loadUserPurchasingInfo;
@end

@implementation UASubscriptionInventory
@synthesize subscriptions;
@synthesize userSubscriptions;
@synthesize hasLoaded;
@synthesize serverDate;

- (void)dealloc {
    RELEASE_SAFELY(subscriptions);
    RELEASE_SAFELY(userSubscriptions);
    RELEASE_SAFELY(subscriptionDict);
    RELEASE_SAFELY(userPurchasingInfo);
    RELEASE_SAFELY(products);
    RELEASE_SAFELY(contents);
    RELEASE_SAFELY(serverDate);
    [super dealloc];
}

- (id)init {
    if (!(self = [super init]))
        return nil;

    subscriptions = [[NSMutableArray alloc] init];
    userSubscriptions = [[NSMutableArray alloc] init];
    subscriptionDict = [[NSMutableDictionary alloc] init];

    products = [[UAProductInventory alloc] init];
    contents = [[UAContentInventory alloc] init];
    [products addObserver:self];
    [contents addObserver:self];

    hasLoaded = NO;
    userPurchasingInfoLoaded = NO;
    productsLoaded = NO;
    contentsLoaded = NO;

    return self;
}

#pragma mark -

- (BOOL)containsProduct:(NSString *)productID {
    return [products containsProduct:productID];
}

- (UASubscriptionContent *)contentForKey:(NSString *)contentKey {
    return [contents contentForKey:contentKey];
}

- (UASubscriptionProduct *)productForKey:(NSString *)productKey {
    return [products productForKey:productKey];
}

- (UASubscription *)subscriptionForKey:(NSString *)subscriptionKey {
    return [subscriptionDict objectForKey:subscriptionKey];
}

- (UASubscription *)subscriptionForProduct:(UASubscriptionProduct *)product {
    return [subscriptionDict objectForKey:product.subscriptionKey];
}

- (UASubscription *)subscriptionForContent:(UASubscriptionContent *)content {
    return [subscriptionDict objectForKey:content.subscriptionKey];
}

#pragma mark -
#pragma mark Load Subscriptions

/*
 * A full reload on all products, purchased contents and purchasing info
 */
- (void)loadInventory {

    // do not load the inventory if the user is not fully initialized
    UAUserState userState = [UAUser defaultUser].userState;
    if (userState == UAUserStateEmpty || userState == UAUserStateCreating) {
        return;
    }

    hasLoaded = NO;

    [self loadProducts];
    [self loadPurchases];
}

- (void)loadProducts {
    productsLoaded = NO;
    [products loadInventory];
}

- (void)loadPurchases {
    contentsLoaded = NO;
    [contents loadInventory];
    userPurchasingInfoLoaded = NO;
    [self loadUserPurchasingInfo];
}

/*
 * This method should only be called after products are loaded
 *
 * Created all available subscriptions
 */
- (void)createSubscription {
    [subscriptionDict removeAllObjects];
    [subscriptions removeAllObjects];

    // create subscriptions from products
    NSArray *keyArray = [[products.productDict allValues] valueForKeyPath:@"@distinctUnionOfObjects.subscriptionKey"];
    for (NSString *subscriptionKey in keyArray) {
        
        NSArray *productArray = [products productsForSubscription:subscriptionKey];
        if ([productArray count] == 0) {
            UALOG(@"No products found for subscription key=%@", subscriptionKey);
            continue;
        }

        UASubscription *subscription = [subscriptionDict valueForKey:subscriptionKey];
        if (!subscription) {
            subscription = [[[UASubscription alloc]
                             initWithKey:subscriptionKey
                             name:[[productArray objectAtIndex:0] subscriptionName]]
                            autorelease];
            [subscriptionDict setObject:subscription forKey:subscriptionKey];
            [subscriptions addObject:subscription];
        }

        [subscription setProductsWithArray:productArray];
    }

    [subscriptions sortUsingSelector:@selector(compare:)];

    // notify availableSubscriptionsUpdated before processing user specific data
    [[UASubscriptionManager shared] subscriptionsUpdated:subscriptions];
}

/*
 * This method will be called after purchases are loaded
 *
 * Create user specific subscriptions with their contents
 * after all available subscriptions are created
 */
- (void)createUserSubscription {

    if (!(productsLoaded && contentsLoaded && userPurchasingInfoLoaded))
        return;

    [userSubscriptions removeAllObjects];

    NSArray *keyArray = [userPurchasingInfo valueForKeyPath:@"@distinctUnionOfObjects.subscription_key"];
    for (NSString *subscriptionKey in keyArray) {
        UASubscription *subscription = [subscriptionDict objectForKey:subscriptionKey];

        if (subscription) {
            // set user purchased products
            NSArray *filteredInfo = [userPurchasingInfo filteredArrayUsingPredicate:
                                     [NSPredicate predicateWithFormat:@"subscription_key like[c] %@", subscriptionKey]];
            [subscription setPurchasedProductsWithArray:filteredInfo];
            [userSubscriptions addObject:subscription];

            // set user available contents
            [subscription setContentWithArray:[contents contentForSubscription:subscriptionKey]];
        }
    }

    [userSubscriptions sortUsingSelector:@selector(compare:)];

    [userPurchasingInfo release];
    userPurchasingInfo = nil;

    hasLoaded = YES;
    [[UASubscriptionManager shared] userSubscriptionsUpdated:userSubscriptions];
}

#pragma mark -
#pragma mark PurchaseRequest Failure Handler

- (void)purchaseRequestWentWrong:(UA_ASIHTTPRequest*)request {
    [UAUtils requestWentWrong:request];

    SKPaymentTransaction *transaction = [request.userInfo objectForKey:@"transaction"];

	// Do not finish the transaction here, leave it open for iOS to re-deliver until it explicitly fails or works
	UALOG(@"Purchase product failed: %@", transaction.payment.productIdentifier);

}

#pragma mark -
#pragma mark Load User Subscriptions

- (void)loadUserPurchasingInfo {
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@/",
                           [UAirship shared].server,
                           @"/api/user/",
                           [UAUser defaultUser].username];
    NSURL *url = [NSURL URLWithString:urlString];

    UA_ASIHTTPRequest *request = [UAUtils userRequestWithURL:url
                                                      method:@"GET"
                                                    delegate:self
                                                      finish:@selector(userPurchasingInfoLoaded:)
                                                        fail:@selector(purchaseInfoRequestFailed:)];
    [request startAsynchronous];
}

- (void)userPurchasingInfoLoaded:(UA_ASIHTTPRequest *)request {
    
    UALOG(@"User products loaded: %d\n%@\n", request.responseStatusCode, request.responseString);
    
    switch (request.responseStatusCode) {
        case 200:
        {
            UA_SBJsonParser *parser = [[UA_SBJsonParser alloc] init];
            NSDictionary *result = [parser objectWithString:request.responseString];
            [parser release];
            
            [self setUserPurchaseInfo:result];
            break;
        }
        case 404://current status, will be removed
        case 401://replacement status
        {
            //replace the current user with a freshone from the server
            [[UAUser defaultUser] createUser];
            break;
            
        }
        default:
        {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setObject:[request.url absoluteString] forKey:NSErrorFailingURLStringKey];
            [userInfo setObject:UASubscriptionPurchaseInventoryFailure forKey:NSLocalizedDescriptionKey];
            
            NSError *error = [NSError errorWithDomain:@"com.urbanairship" code:request.responseStatusCode userInfo:userInfo];
            [[UASubscriptionManager shared] inventoryUpdateFailedWithError:error];
            break;
        }
    }
    
}

- (void)purchaseInfoRequestFailed:(UA_ASIHTTPRequest *)request {
    
    UALOG(@"Purchase info request failed.");
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:[request.url absoluteString] forKey:NSErrorFailingURLStringKey];
    [userInfo setObject:UASubscriptionPurchaseInventoryFailure forKey:NSLocalizedDescriptionKey];
    
    NSError *error = [NSError errorWithDomain:@"com.urbanairship" code:request.responseStatusCode userInfo:userInfo];
    [[UASubscriptionManager shared] inventoryUpdateFailedWithError:error];
}

- (void)setUserPurchaseInfo:(NSDictionary *)userInfo {
    
    [userPurchasingInfo release];
    userPurchasingInfo = [[userInfo objectForKey:@"subscriptions"] retain];
    
    hasActiveSubscriptions = ([[userInfo objectForKey:@"has_active_subscription"] intValue] == 1) ? YES : NO;
    
    NSDateFormatter *generateDateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
	
	[generateDateFormatter setLocale:enUSPOSIXLocale];
	[generateDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"]; //2010-07-20 15:48:46
	[generateDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    // refs http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns
    // Date Format Patterns 'ZZZ' is for date strings like '-0800' and 'ZZZZ'
    // is used for 'GMT-08:00', so i just set the timezone string as '+0000' which
    // is equal to 'UTC'
    NSString *str = [NSString stringWithFormat: @"%@%@", [userInfo objectForKey:@"server_time"], @" +0000"];
    self.serverDate = [generateDateFormatter dateFromString: str];
    
    userPurchasingInfoLoaded = YES;
    [self createUserSubscription];
}

#pragma mark Load User Subscription Contents

- (void)contentInventoryUpdated {
    contentsLoaded = YES;
    [self createUserSubscription];
}

#pragma mark Load All Subscription Products

- (void)productInventoryUpdated {
    productsLoaded = YES;
    [self createSubscription];
    [self createUserSubscription];
}

#pragma mark -
#pragma mark Purchase Subscription Product

- (void)purchase:(UASubscriptionProduct *)product {
    [[SKPaymentQueue defaultQueue] addPayment:
     [SKPayment paymentWithProduct:product.skProduct]];
    product.isPurchasing = YES;
}

- (void)subscriptionTransctionDidComplete:(SKPaymentTransaction *)transaction {
    UASubscriptionProduct *product = [self productForKey:transaction.payment.productIdentifier];
    NSString *key = product.subscriptionKey;
    NSString *product_id = transaction.payment.productIdentifier;
    NSString *receipt = [[[NSString alloc] initWithData:transaction.transactionReceipt
                                               encoding:NSUTF8StringEncoding] autorelease];

    NSString *urlString = [NSString stringWithFormat:@"%@%@%@/subscriptions/%@/purchase",
                           [[UAirship shared] server],
                           @"/api/user/",
                           [UAUser defaultUser].username,
                           key];

    UA_ASIHTTPRequest *request = [UAUtils userRequestWithURL:[NSURL URLWithString:urlString]
                                                   method:@"POST"
                                                 delegate:self
                                                   finish:@selector(subscriptionPurchased:)
                                                     fail:@selector(purchaseRequestWentWrong:)];

    request.userInfo = [NSDictionary dictionaryWithObject:transaction forKey:@"transaction"];

    UA_SBJsonWriter *writer = [[UA_SBJsonWriter alloc] init];
    writer.humanReadable = NO;
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                 product_id,
                                 @"product_id",
                                 receipt,
                                 @"transaction_receipt",
                                 nil];
    NSString *body = [writer stringWithObject:data];
    [data release];
    [writer release];

    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendPostData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request startAsynchronous];
}

- (void)subscriptionPurchased:(UA_ASIHTTPRequest *)request {
    
    UALOG(@"Subscription purchased: %d\n%@\n", request.responseStatusCode, request.responseString);
    
    SKPaymentTransaction *transaction = [request.userInfo objectForKey:@"transaction"];
    UASubscriptionProduct *product =
        [[UASubscriptionManager shared].inventory productForKey:transaction.payment.productIdentifier];
    
    BOOL isRenewal = (transaction.transactionState == SKPaymentTransactionStateRestored);
    
    switch (request.responseStatusCode) {
        case 200:
        {
            
            //close the transaction
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            
            //notify the observers
            if (isRenewal) {
                UALOG(@"Notifying renewal observers");
                [[UASubscriptionManager shared] notifyObservers:@selector(subscriptionProductRenewed:) withObject:product];
            } else {
                [[UASubscriptionManager shared] purchaseProductFinished:product];
            }
            
            // Reload purchased contents and info. No need to reload products
            [self loadPurchases];
            break;
        }
        case 212: // user merged
        {
            UALOG(@"Subscription restored from another user!");
            
            UA_SBJsonParser *parser = [[UA_SBJsonParser alloc] init];
            NSDictionary *responseDictionary = [parser objectWithString:request.responseString];
            [parser release];
            
            NSDictionary *userData = [responseDictionary objectForKey:@"user_data"];
            [[UAUser defaultUser] didMergeWithUser:userData];
            [self setUserPurchaseInfo:userData];
            
            // close the transaction
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            
            //notify the observers
            if (isRenewal) {
                [[UASubscriptionManager shared] notifyObservers:@selector(subscriptionProductRenewed:) withObject:product];
            } else {
                [[UASubscriptionManager shared] purchaseProductFinished:product];
            }
            
            break;
        }
        default:
        {
            [self purchaseRequestWentWrong:request];
            break;
        }
    }

}

#pragma mark -
#pragma mark Download Subscription Product

- (void)download:(UASubscriptionContent *)content {
    [[UASubscriptionManager shared].downloadManager download:content];
}

@end
