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

#import "UAStoreFront.h"
#import "UAUtils.h"
#import "UAStoreKitObserver.h"
#import "UAInventory.h"
#import "UAStoreFrontDownloadManager.h"
#import "UAStoreFrontAlertProtocol.h"

// Weak link to this notification since it doesn't exist in iOS 3.x
UIKIT_EXTERN NSString* const UIApplicationDidEnterBackgroundNotification __attribute__((weak_import));

@implementation UAStoreKitObserver

@synthesize inRestoring;

- (id)init {
    if (!(self = [super init]))
        return nil;

    inRestoring = NO;

    IF_IOS4_OR_GREATER(
        if (&UIApplicationDidEnterBackgroundNotification != NULL) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(enterBackground)
                                                         name:UIApplicationDidEnterBackgroundNotification
                                                       object:nil];
        }
                       );

    return self;
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    RELEASE_SAFELY(unRestoredTransactions);
    [super dealloc];
}

- (void)setInRestoring:(BOOL)value {
    if (inRestoring != value) {
        inRestoring = value;
        [self notifyObservers:@selector(restoreStatusChanged:)
                   withObject:[NSNumber numberWithBool:inRestoring]];
    }
}

- (UAProduct *)productFromTransaction:(SKPaymentTransaction *)transaction {
    NSString *identifier = transaction.payment.productIdentifier;
    UAProduct *product = [[UAStoreFront shared].inventory productWithIdentifier:identifier];
    if (transaction.transactionState == SKPaymentTransactionStatePurchased
        || transaction.transactionState == SKPaymentTransactionStateRestored)
        product.receipt = [[[NSString alloc] initWithData:transaction.transactionReceipt
                                                 encoding:NSUTF8StringEncoding] autorelease];
    return product;
}

#pragma mark -
#pragma mark SKPaymentTransaction lifecycle handler

- (void)startTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Transaction started: %@, id: %@", transaction, transaction.payment.productIdentifier);
    UAProduct *product = [self productFromTransaction:transaction];
    product.status = UAProductStatusWaiting;
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Purchase Successful, provide content.\n completeTransaction: %@ \t id: %@",
          transaction, transaction.payment.productIdentifier);
    [[UAStoreFront shared].downloadManager downloadIfValid:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Restore Transaction: %@ id: %@", transaction, transaction.payment.productIdentifier);
    NSString *productIdentifier = transaction.payment.productIdentifier;
    if (inRestoring) {
        UALOG(@"Original transaction: %@", transaction.originalTransaction);
        // when a transaction restored, we don't directly verify and download
        // contents but just put it into unRestoredTransactions. The
        // unRestoredTransactions is used to count how many items can be
        // restored and been alert to user, all the transactions will be
        // download only after user click 'OK' in the alert view

        if ([[UAStoreFront shared].inventory hasProductWithIdentifier:productIdentifier] == NO) {
            UALOG(@"Product no longer exists in inventory: %@", productIdentifier);
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            return;
        }

        if (unRestoredTransactions == nil) {
            unRestoredTransactions = [[NSMutableArray alloc] init];
        }

        // filter out previous duplicate restore transaction
        BOOL contains = NO;
        for (SKPaymentTransaction *tran in unRestoredTransactions) {
            if ([tran.payment.productIdentifier isEqual:productIdentifier]) {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                contains = YES;
                break;
            }
        }
        if (!contains) {
            UALOG(@"Add transaction into unRestoreTransactions array: %@", productIdentifier);
            [unRestoredTransactions addObject:transaction];
        }

    } else {
        // if it's not inRestoring, the transaction should be added by StoreKit
        // automatically. Due to apple's internal policies, we cann't restore
        // prior purchases behind the scenes, so directly finish the transaction
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    if ((int)transaction.error.code != SKErrorPaymentCancelled) {
        UALOG(@"Transaction Failed (%d), product: %@", (int)transaction.error.code, transaction.payment.productIdentifier);
        id<UAStoreFrontAlertProtocol> alertHandler = [[[UAStoreFront shared] uiClass] getAlertHandler];
        [alertHandler showPaymentTransactionFailedAlert];
    }

    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

    // If canceled because of being a duplicate transaction
    BOOL needReset = YES;
    NSArray *tranArray = [SKPaymentQueue defaultQueue].transactions;
    for (SKPaymentTransaction *tran in tranArray) {
        if (transaction != tran && [transaction.payment.productIdentifier isEqualToString:tran.payment.productIdentifier]) {
            needReset = NO;
            break;
        }
    }

    if (needReset) {
        UAProduct *product = [self productFromTransaction:transaction];
        [product resetStatus];
    }
}

- (void)finishTransaction:(SKPaymentTransaction *)transaction {
    if (transaction) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}


#pragma mark -
#pragma mark SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
    UALOG(@"paymentQueue:removedTransaction:%@", transactions);
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
    self.inRestoring = NO;
    for (SKPaymentTransaction *transaction in unRestoredTransactions) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        UAProduct *product = [self productFromTransaction:transaction];
        [product resetStatus];
    }

    RELEASE_SAFELY(unRestoredTransactions);
    UALOG(@"paymentQueue:%@ restoreCompletedTransactionsFailedWithError:%@", queue, error);

}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    UALOG(@"paymentQueueRestoreCompletedTransactionsFinished:%@", queue);
    self.inRestoring = NO;
    id<UAStoreFrontAlertProtocol> alertHandler = [[[UAStoreFront shared] uiClass] getAlertHandler];
    [alertHandler showConfirmRestoringAlert:[unRestoredTransactions count]
                                   delegate:self approveSelector:@selector(downloadAllRestoredItems)
                         disapproveSelector:@selector(discardAllRestoredItems)];
}

- (void)downloadAllRestoredItems {
    for (SKPaymentTransaction *transaction in unRestoredTransactions) {
        [[UAStoreFront shared].downloadManager downloadIfValid:transaction];
    }
    RELEASE_SAFELY(unRestoredTransactions);
}

- (void)discardAllRestoredItems {
    for (SKPaymentTransaction *transaction in unRestoredTransactions) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
    RELEASE_SAFELY(unRestoredTransactions);
}

#pragma mark -
#pragma mark Pay for product

- (void)payForProduct:(SKProduct *)product {
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

#pragma mark -
#pragma mark Resotre all completed transactions

- (void)restoreAll {
    self.inRestoring = YES;
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark -
#pragma mark Inventory observer methods

- (void)inventoryStatusChanged:(NSNumber *)status {
    if ([status intValue] == UAInventoryStatusLoaded) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
}

// App is backgrounding, remove transactionObserver
- (void)enterBackground {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

@end
