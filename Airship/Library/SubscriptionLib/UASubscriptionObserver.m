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

#import "UASubscriptionObserver.h"

#import "UAirship.h"
#import "UAUtils.h"
#import "UAUser.h"
#import "UASubscriptionManager.h"
#import "UAProductInventory.h"
#import "UASubscriptionProduct.h"
#import "UASubscriptionInventory.h"

#import "UA_ASIHTTPRequest.h"
#import "UA_ASINetworkQueue.h"
#import "UASubscriptionAlertProtocol.h"

#import "UA_SBJSON.h"
#import "UA_ZipArchive.h"

// for IAP Compatibility
#import "UAStoreFront.h"
#import "UAInventory.h"
#import "UAStoreKitObserver.h"

#pragma mark -
#pragma mark Private Category
// Private methods
@interface UASubscriptionObserver()

/**
 * Finish a transaction if it is still present in the queue.
 *
 * @param transaction The transaction to finish
 */
- (void)safelyFinishTransaction:(SKPaymentTransaction *)transaction;

/**
 * Finish a transaction if it is still present in the queue, but only if the product
 * is in the inventory or NOT in the IAP inventory
 *
 * @param transaction The transaction to finish
 */
- (void)safelyFinishUnknownTransaction:(SKPaymentTransaction *)transaction;

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

/** Logs transaction identifiers and dates. */
- (void)logTransaction:(SKPaymentTransaction *)transaction;
@end

#pragma mark -
#pragma mark UASubscriptionObserver implementation
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
    
    // If StoreFrontLib is in use, tell its observer that we're restoring products
    // Ties SubscriptionLib to StoreFrontLib - consider making these weak references once we drop 3.x support
    if ([UAStoreFront initialized]) {
        [[UAStoreFront shared].sfObserver setRestoring:YES];
    }
    
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

    BOOL canceled = NO;
    if ((int)error.code == SKErrorPaymentCancelled) {
        canceled = YES;
    }
    
    UALOG(@"Restore Failed");
    if (self.alertDelegate && [self.alertDelegate respondsToSelector:@selector(showAlert:for:)] && !canceled) {
        [self.alertDelegate showAlert:UASubscriptionAlertFailedRestore for:nil];
    }

    //close any of the transactions that were passed back and clear out the list to try again
    for (SKPaymentTransaction *transaction in unrestoredTransactions) {
        [self safelyFinishTransaction:transaction];
    }
    [unrestoredTransactions removeAllObjects];
    
    restoring = NO;
    
    //notify observers
    [[UASubscriptionManager shared] restoreAutorenewablesFailedWithError:error];
    
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
        [self safelyFinishUnknownTransaction:transaction];
    }
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Purchase Successful for Product ID: %@", transaction.payment.productIdentifier);
    [self logTransaction:transaction];
    
    // If the product was purchased previously, but no longer exits on UA
    // we can not complete this transaction, so we'll close it
    NSString *productIdentifier = transaction.payment.productIdentifier;
    if (![[UASubscriptionManager shared].inventory containsProduct:productIdentifier]) {
        UALOG(@"Product no longer exists in inventory: %@", productIdentifier);
        [self safelyFinishUnknownTransaction:transaction];
    } else {
        [[UASubscriptionManager shared].inventory subscriptionTransctionDidComplete:transaction];
    }
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    
    NSString *productIdentifier = transaction.payment.productIdentifier;
    UALOG(@"Restoring Transaction for Product ID: %@", productIdentifier);
    [self logTransaction:transaction];
    
    UASubscriptionProduct *product = [[UASubscriptionManager shared].inventory productForKey:productIdentifier];

    if (product && product.autorenewable && restoring) {
    
        [unrestoredTransactions addObject:transaction];
        [self submitRestoredTransaction:transaction];
        
    } else if (product && product.autorenewable) {
        
        // Uncomment to clear out all transactions - helpful for debugging
        // [self safelyFinishTransaction:transaction];
        // return;//don't do anything else
        
        
        // if we did not start the restore process, treat this as a renewal
        // and send it through the purchase process
        UALOG(@"Renewing Subscription Product ID: %@", productIdentifier);
        [[UASubscriptionManager shared].inventory subscriptionTransctionDidComplete:transaction];
        
    } else {
        UALOG(@"Skipping transaction - unknown product or not an autorenewable.");
        [self safelyFinishUnknownTransaction:transaction];
    }

}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
    NSString *productIdentifier = transaction.payment.productIdentifier;
    UASubscriptionProduct *product = [[UASubscriptionManager shared].inventory productForKey:productIdentifier];
    
    if ((int)transaction.error.code != SKErrorPaymentCancelled) {
        UALOG(@"Transaction Failed (%@), product: %@", (int)transaction.error, productIdentifier);
        if (self.alertDelegate && [self.alertDelegate respondsToSelector:@selector(showAlert:for:)]) {
            [self.alertDelegate showAlert:UASubscriptionAlertFailedTransaction for:nil];
        }
    }

    [[UASubscriptionManager shared] purchaseProductFailed:product withError:transaction.error];
    [self safelyFinishTransaction:transaction];

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
    
    [networkQueue addOperation:request];
}

- (void)autorenewableRestoredWithRequest:(UA_ASIHTTPRequest *)request {
    
    UALOG(@"Subscription restored or renewed: %d\n%@\n", request.responseStatusCode, request.responseString);
    
    SKPaymentTransaction *transaction = [request.userInfo objectForKey:@"transaction"];
    UASubscriptionProduct *product = [[UASubscriptionManager shared].inventory productForKey:transaction.payment.productIdentifier];
    
    switch (request.responseStatusCode) {
        case 200:
        {

            // close the transaction, even if verification failed - it's restorable
            [unrestoredTransactions removeObject:transaction];
            [self safelyFinishTransaction:transaction];
            
            // First, check to see if the receipt was verified
            // if not, notify observers and bail if the receipt verification failed
            if (![UASubscriptionInventory isReceiptValid:request.responseString]) {
                UALOG(@"Recipt validation failed: %@", request.responseString);
                
                //notify observers
                [[UASubscriptionManager shared] restoreAutorenewableProductFailed:product];
                
            } else if (![restoredProducts containsObject:product]) {
                [restoredProducts addObject:product];
            }
            
            // Purchases will be reloaded when the last transaction is complete
            
            break;
        }
        case 212:
        {
            UALOG(@"Subscription restored from another user!");
            
            UA_SBJsonParser *parser = [[UA_SBJsonParser alloc] init];
            NSDictionary *responseDictionary = [parser objectWithString:request.responseString];
            [parser release];
            
            NSDictionary *userData = [responseDictionary objectForKey:@"user_data"];
            [[UAUser defaultUser] didMergeWithUser:userData];
            [[UASubscriptionManager shared].inventory setUserPurchaseInfo:userData];
            
            // close the transaction
            [unrestoredTransactions removeObject:transaction];
            [self safelyFinishTransaction:transaction];
            
            if (![restoredProducts containsObject:product]) {
                [restoredProducts addObject:product];
            }
            
            //UALOG(@"Request count: %d", networkQueue.requestsCount);
            if (networkQueue.requestsCount > 1) {
                //rebuild the other transactions
                //UALOG(@"Rebuilding receipt submission request: %d more requests", networkQueue.requestsCount);
                
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
    
    // close the transaction
    if ([request isCancelled]) {
        return;//if it was cancelled, it will be retried after the merge
    }
    
    [unrestoredTransactions removeObject:transaction];
    [self safelyFinishTransaction:transaction];
    
    //notify observers
    UASubscriptionProduct *product = [[UASubscriptionManager shared].inventory productForKey:transaction.payment.productIdentifier];
    [[UASubscriptionManager shared] restoreAutorenewableProductFailed:product];
    
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

- (void)logTransaction:(SKPaymentTransaction *)transaction {
    
    NSDateFormatter* dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    UALOG(@"Transaction ID: %@", transaction.transactionIdentifier);
    UALOG(@"Transaction Date: %@", [dateFormatter stringFromDate:transaction.transactionDate]);

    if (transaction.originalTransaction) {
        UALOG(@"Original Transaction ID: %@", transaction.originalTransaction.transactionIdentifier);
        UALOG(@"Original Transaction Date: %@", [dateFormatter stringFromDate:transaction.originalTransaction.transactionDate]);
    }
    
}

#pragma mark -
#pragma mark Transaction Management

- (void)safelyFinishTransaction:(SKPaymentTransaction *)transaction {
    if (transaction && [[[SKPaymentQueue defaultQueue] transactions] containsObject:transaction]) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

- (void)safelyFinishUnknownTransaction:(SKPaymentTransaction *)transaction {
    if (transaction && [[[SKPaymentQueue defaultQueue] transactions] containsObject:transaction]) {

        // Tests the transaction against the StoreFront inventory
        // Ties SubscriptionLib to StoreFrontLib - consider making these weak references once we drop 3.x support
        if ([UAStoreFront initialized]) {
            
            UAInventoryStatus iapStatus = [UAStoreFront shared].inventory.status;
            NSString *identifier = transaction.payment.productIdentifier;
            
            // if purchasing is disabled, finish the transaction
            // if the inventory is loaded and does not contain the product ID, finish the transaction
            if (iapStatus == UAInventoryStatusPurchaseDisabled ||
                (iapStatus == UAInventoryStatusLoaded && ![[UAStoreFront shared].inventory productWithIdentifier:identifier])) {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
            
        } else {
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
    }
}

@end