/*
Copyright 2009-2011 Urban Airship Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binaryform must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided withthe distribution.

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

#import "UAirship.h"
#import "UAUtils.h"
#import "UASubscriptionObserver.h"
#import "UASubscriptionManager.h"
#import "UAProductInventory.h"
#import "UASubscriptionProduct.h"
#import "UASubscriptionInventory.h"

#import "UA_SBJSON.h"
#import "UA_ZipArchive.h"

// Private methods
@interface UASubscriptionObserver()

/**
 * Creates and initializes a network queue for sequentially submitting
 * receipts to Urban Airship. Max concurrent connections = 1, calls
 * autorenewableRestoreRequestsCompleted on success
 */
- (void)createNetworkQueue;

/**
 * Submits an autorenewable transaction receipt to Urban Airship.
 */
- (void)submitRestoredTransaction:(SKPaymentTransaction *)transaction;
- (void)autorenewableRestoredWithRequest:(UA_ASIHTTPRequest *)request;
- (void)autorenewableRestoreRequestDidFail:(UA_ASIHTTPRequest *)request;
- (void)autorenewableRestoreRequestsCompleted;


- (void)startTransaction:(SKPaymentTransaction *)transaction;
- (void)completeTransaction:(SKPaymentTransaction *)transaction;
- (void)failedTransaction:(SKPaymentTransaction *)transaction;
- (void)restoreTransaction:(SKPaymentTransaction *)transaction;
@end

@implementation UASubscriptionObserver

@synthesize alertDelegate;

- (id)init {
    if (!(self = [super init])) {
        return nil;
    }

    unrestoredTransactions = [[NSMutableArray alloc] init];
    restoredProducts = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc {
    [networkQueue cancelAllOperations];
    RELEASE_SAFELY(networkQueue);
    RELEASE_SAFELY(unrestoredTransactions);
    RELEASE_SAFELY(restoredProducts);
    alertDelegate = nil;
    
    [super dealloc];
}

#pragma mark -
#pragma mark Restore All Subscriptions
- (void)restoreAutorenewables {
    if (restoring) {
        UALOG(@"A restore is already in progress.");
        return;
    }
    
    UALOG(@"Restoring all autorenewable subscriptions");
    restoring = YES;
    [self createNetworkQueue];
    [unrestoredTransactions removeAllObjects];
    [restoredProducts removeAllObjects];
    
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark -
#pragma mark SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
    UALOG(@"paymentQueue:removedTransaction:%@", transactions);
    UASubscriptionManager *manager = [UASubscriptionManager shared];
    for (SKPaymentTransaction *transaction in transactions) {
        UASubscriptionProduct *product = [manager.inventory productForKey:transaction.payment.productIdentifier];
        product.isPurchasing = NO;
        [manager purchaseProductFinished:product];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                [self startTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
                break;
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {

        UALOG(@"Restore Failed");
        if (self.alertDelegate && [self.alertDelegate respondsToSelector:@selector(showAlert:for:)]) {
            [self.alertDelegate showAlert:UASubscriptionAlertFailedRestore for:nil];
        }
    
    //close any of the transactions that were passed back and clear out the list to try again
    for (SKPaymentTransaction *transaction in unrestoredTransactions) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
    [unrestoredTransactions removeAllObjects];
    
    restoring = NO;
    
    UALOG(@"paymentQueue:%@ restoreCompletedTransactionsFailedWithError:%@", queue, error);
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    UALOG(@"paymentQueueRestoreCompletedTransactionsFinished:%@", queue);

    if ([unrestoredTransactions count] > 0) {
        UALOG(@"Starting queue. Request count: %d", networkQueue.requestsCount);
        [networkQueue go];
    } else {
        [self autorenewableRestoreRequestsCompleted];
    }
}

#pragma mark -
#pragma mark Transaction result handlers

- (void)startTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Transaction started");
    
    // If the product was purchased previously, but no longer exits on UA
    // We can not restore it.
    NSString *productIdentifier = transaction.payment.productIdentifier;
    if (![[UASubscriptionManager shared].inventory containsProduct:productIdentifier]) {
        UALOG(@"Product no longer exists in inventory: %@", productIdentifier);
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Purchase Successful, provide content.\n completeTransaction: %@ id: %@ receipt: %@",
          transaction,
          transaction.payment.productIdentifier,
          transaction.transactionReceipt);
    
    [[UASubscriptionManager shared].inventory subscriptionTransctionDidComplete:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    
    //UALOG(@"Restore Transaction: %@", transaction);
    //UALOG(@"id: %@ ||| original transaction: %@ ||| original receipt: %@\n", 
    //      transaction.payment.productIdentifier,
    //      transaction.originalTransaction, 
    //      transaction.originalTransaction.transactionReceipt);
    
    NSString *productIdentifier = transaction.payment.productIdentifier;
    UALOG(@"Restoring Transaction for Product ID: %@", productIdentifier);
    
    UASubscriptionProduct *product = [[UASubscriptionManager shared].inventory productForKey:productIdentifier];
    if (product && product.autorenewable && restoring) {
        [unrestoredTransactions addObject:transaction];
        [self submitRestoredTransaction:transaction];
    } else {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }

}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    if ((int)transaction.error.code != SKErrorPaymentCancelled) {
        UALOG(@"Transaction Failed (%@), product: %@", (int)transaction.error, transaction.payment.productIdentifier);
        if (self.alertDelegate && [self.alertDelegate respondsToSelector:@selector(showAlert:for:)]) {
            [self.alertDelegate showAlert:UASubscriptionAlertFailedTransaction for:nil];
        }
    }

    if (transaction) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

#pragma mark -
#pragma mark Subscription restore request methods

- (void)submitRestoredTransaction:(SKPaymentTransaction *)transaction {
    UASubscriptionProduct *product = [[UASubscriptionManager shared].inventory productForKey:transaction.payment.productIdentifier];
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
                                                      finish:@selector(autorenewableRestoredWithRequest:)
                                                        fail:@selector(autorenewableRestoreRequestDidFail:)];
    
    request.userInfo = [NSDictionary dictionaryWithObject:transaction forKey:@"transaction"];
    
    UA_SBJsonWriter *writer = [[UA_SBJsonWriter alloc] init];
    writer.humanReadable = NO;
    
    NSMutableDictionary* data = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                 product_id,
                                 @"product_id",
                                 receipt,
                                 @"transaction_receipt",
                                 nil];
    NSString* body = [writer stringWithObject:data];
    [data release];
    [writer release];
    
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendPostData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    
    [networkQueue addOperation:request];
}

- (void)autorenewableRestoredWithRequest:(UA_ASIHTTPRequest *)request {
    
    UALOG(@"Subscription purchased: %d\n%@\n", request.responseStatusCode, request.responseString);
    
    SKPaymentTransaction *transaction = [request.userInfo objectForKey:@"transaction"];
    UASubscriptionProduct *product = [[UASubscriptionManager shared].inventory productForKey:transaction.payment.productIdentifier];
    
    switch (request.responseStatusCode) {
        case 200:
        {
            // close the transaction
            [unrestoredTransactions removeObject:transaction];
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            
            if (![restoredProducts containsObject:product]) {
                [restoredProducts addObject:product];
            }
            
            // Purchases will be reloaded when the last transaction is complete
            
            break;
        }
        case 212:
        {
            UALOG(@"Subscription restored from another user!");
            
            // Sample response:
            /*
             {"user_data": 
             {"has_active_subscription": true, 
             "user_url": "https://sgc.urbanairship.com/api/user/4e20bc17a9ee251feb000001/", 
             "subscriptions": [
             {"subscription_key": "d5PFDJyBSwukGaRiZheuNw", "end": "2011-07-15 22:20:13", "product_id": "com.urbanairship.artest.7days", "is_active": false, "start": "2011-07-15 22:17:13", "purchased": "2011-07-15 22:17:13"},
             {"subscription_key": "d5PFDJyBSwukGaRiZheuNw", "end": "2011-07-15 22:27:59", "product_id": "com.urbanairship.artest.7days", "is_active": true, "start": "2011-07-15 22:24:59", "purchased": "2011-07-15 22:24:59"}
             ],
             "user_id": "4e20bc17a9ee251feb000001",
             "server_time": "2011-07-15 22:25:00",
             "password": "-4GNBzU5RA2sAt0B2TPLNA",
             "device_tokens": ["BF58148F2142DF6A843710BBEADC513916DB26B015EBA610BF86C457FD171B37"]
             }
             }
             */
            
            UA_SBJsonParser *parser = [[UA_SBJsonParser alloc] init];
            NSDictionary *responseDictionary = [parser objectWithString:request.responseString];
            [parser release];
            
            NSDictionary *userData = [responseDictionary objectForKey:@"user_data"];
            [[UAUser defaultUser] didMergeWithUser:userData];
            [[UASubscriptionManager shared].inventory setUserPurchaseInfo:userData];
            
            // close the transaction
            [unrestoredTransactions removeObject:transaction];
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            
            if (![restoredProducts containsObject:product]) {
                [restoredProducts addObject:product];
            }
            
            UALOG(@"Request count: %d", networkQueue.requestsCount);
            if (networkQueue.requestsCount > 1) {
                //rebuild the other transactions
                UALOG(@"Rebuilding receipt submission request: %d more requests", networkQueue.requestsCount);
                
                [networkQueue setDelegate:nil];//remove delegate to prevent cancel events
                [networkQueue cancelAllOperations];
                RELEASE_SAFELY(networkQueue);
                
                [self createNetworkQueue];
                
                for (SKPaymentTransaction *unsubmitted in unrestoredTransactions) {
                    [self submitRestoredTransaction:unsubmitted];
                }
                [networkQueue go];
                
            }
            
            break;
        }
        default:
        {
            [self autorenewableRestoreRequestDidFail:request];
            break;
        }
    }
    
}

- (void)autorenewableRestoreRequestDidFail:(UA_ASIHTTPRequest *)request {
    
    SKPaymentTransaction *transaction = [request.userInfo objectForKey:@"transaction"];
    
    //notify observers
    [[UASubscriptionManager shared] restoreAutorenewablesFailed];
    [restoredProducts removeAllObjects];
    
	// Do not finish the transaction here, leave it open for iOS to re-deliver until it explicitly fails or works
	UALOG(@"Restore product failed: %@", transaction.payment.productIdentifier);
    
}

- (void)autorenewableRestoreRequestsCompleted {
    restoring = NO;
    
    //notify observers
    [[UASubscriptionManager shared] restoreAutorenewablesFinished:restoredProducts];
    [restoredProducts removeAllObjects];//remove references
    
    [[UASubscriptionManager shared].inventory loadPurchases];
}

#pragma mark -
#pragma mark Network queue create/reset

- (void)createNetworkQueue {
    RELEASE_SAFELY(networkQueue);
    networkQueue = [[UA_ASINetworkQueue queue] retain];
    [networkQueue setDelegate:self];
    [networkQueue setQueueDidFinishSelector:@selector(autorenewableRestoreRequestsCompleted)];
    [networkQueue setMaxConcurrentOperationCount:1];
}

@end