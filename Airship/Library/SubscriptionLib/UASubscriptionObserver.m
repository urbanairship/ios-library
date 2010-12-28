/*
Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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


@implementation UASubscriptionRequest

@synthesize transaction;
@synthesize product;

- (void)dealloc {
    RELEASE_SAFELY(product);
    RELEASE_SAFELY(transaction);
    [super dealloc];
}

@end

@implementation UASubscriptionObserver
@synthesize alertDelegate;

- (id)init {
    if (!(self = [super init]))
        return nil;

    networkQueue = [[UA_ASINetworkQueue queue] retain];
    [networkQueue go];

    return self;
}

- (void)dealloc {
    [networkQueue cancelAllOperations];
    RELEASE_SAFELY(networkQueue);
    RELEASE_SAFELY(pendingProducts);
    RELEASE_SAFELY(unRestoredTransactions);
    alertDelegate = nil;
    [super dealloc];
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
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    for (SKPaymentTransaction *transaction in unRestoredTransactions) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }

    RELEASE_SAFELY(unRestoredTransactions);
    UALOG(@"paymentQueue:%@ restoreCompletedTransactionsFailedWithError:%@", queue, error);
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    UALOG(@"paymentQueueRestoreCompletedTransactionsFinished:%@", queue);
}

#pragma mark -

- (void)startTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Transaction started");
    return;
    NSString *productIdentifier = transaction.payment.productIdentifier;
    // If the product was purchased previously, but no longer exits on UA
    // We can not restore it.
    if (![[UASubscriptionManager shared].inventory containsProduct:productIdentifier]) {
        UALOG(@"Product no longer exists in inventory: %@", productIdentifier);
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        return;
    }
    // TODO: UI, Prepare download
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Purchase Successful, provide content.\n completeTransaction: %@ id: %@ receipt: %@",
          transaction, transaction.payment.productIdentifier, transaction.transactionReceipt);
    [[UASubscriptionManager shared].inventory subscriptionTransctionDidComplete:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Restore Transaction: %@", transaction);
    UALOG(@"id: %@ ||| original transaction: %@ ||| original receipt: %@", transaction.payment.productIdentifier,
          transaction.originalTransaction, transaction.originalTransaction.transactionReceipt);
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    if ((int)transaction.error.code != SKErrorPaymentCancelled) {
        UALOG(@"Transaction Failed (%@), product: %@", (int)transaction.error, transaction.payment.productIdentifier);
        if (self.alertDelegate != nil && [self.alertDelegate respondsToSelector:@selector(showAlert:for:)]) {
            [self.alertDelegate showAlert:UASubscriptionAlertFailedTransaction for:nil];
        }
    }

    if (transaction)
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

@end