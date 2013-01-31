/*
Copyright 2009-2012 Urban Airship Inc. All rights reserved.

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
#import "UAProduct.h"
#import "UAInventory.h"
#import "UAStoreFrontDownloadManager.h"
#import "UAStoreFrontAlertProtocol.h"
#import "UAStoreFrontDelegate.h"

// Weak link to this notification since it doesn't exist in iOS 3.x
UIKIT_EXTERN NSString * const UIApplicationDidEnterBackgroundNotification __attribute__((weak_import));

@implementation UAStoreKitObserver

@synthesize restoring;

- (id)init {
    if (!(self = [super init]))
        return nil;

    restoring = NO;

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

- (void)setRestoring:(BOOL)value {
    if (restoring != value) {
        restoring = value;
        [self notifyObservers:@selector(restoreStatusChanged:)
                   withObject:[NSNumber numberWithBool:restoring]];
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

- (UAProduct *)productForDownload:(SKDownload *)download {
    return [[UAStoreFront shared].inventory productWithIdentifier:download.contentIdentifier];
}

- (void)productInstallFailed:(UAProduct *)product {
    id<UAStoreFrontAlertProtocol> alertHandler = [[[UAStoreFront shared] uiClass] getAlertHandler];
    if ([alertHandler respondsToSelector:@selector(showDownloadContentFailedAlert)]) {
        [alertHandler showDownloadContentFailedAlert];
    }

    [product resetStatus];
}

- (void)productInstallCancelled:(UAProduct *)product {
    [product resetStatus];
}

- (void)productInstallSucceeded:(UAProduct *)product {
    product.status = UAProductStatusInstalled;
    // Save purchase receipt
    [[UAStoreFront shared] addReceipt:product];
    [[UAStoreFront shared].delegate productPurchased:product];
}

#pragma mark -
#pragma mark SKPaymentTransaction lifecycle handler

- (void)startTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Transaction started: %@, id: %@", transaction, transaction.payment.productIdentifier);
    UAProduct *product = [self productFromTransaction:transaction];
    product.status = UAProductStatusPurchasing;
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Purchase Successful, provide content.\n completeTransaction: %@ \t id: %@",
          transaction, transaction.payment.productIdentifier);
    NSArray *downloads = transaction.downloads;
    //start the download process
    UAProduct *product = [self productFromTransaction:transaction];
    product.status = UAProductStatusDownloading;

    //Note: if desired you can verify the purchase receipt here, before initiating a download

    [[SKPaymentQueue defaultQueue] startDownloads:downloads];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"Restore Transaction: %@ id: %@", transaction, transaction.payment.productIdentifier);
    NSString *productIdentifier = transaction.payment.productIdentifier;
    if (restoring) {
        UALOG(@"Original transaction: %@", transaction.originalTransaction);
        // when a transaction restored, we don't directly verify and download
        // contents but just put it into unRestoredTransactions. The
        // unRestoredTransactions is used to count how many items can be
        // restored and been alert to user, all the transactions will be
        // download only after user click 'OK' in the alert view

        if ([[UAStoreFront shared].inventory hasProductWithIdentifier:productIdentifier] == NO) {
            UALOG(@"Product no longer exists in inventory: %@", productIdentifier);
            [self finishUnknownTransaction:transaction];
            return;
        }

        if (unRestoredTransactions == nil) {
            unRestoredTransactions = [[NSMutableArray alloc] init];
        }

        // filter out previous duplicate restore transaction
        BOOL contains = NO;
        for (SKPaymentTransaction *tran in unRestoredTransactions) {
            if ([tran.payment.productIdentifier isEqual:productIdentifier]) {
                [self finishTransaction:transaction];
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
        [self finishUnknownTransaction:transaction];
    }
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    if ((int)transaction.error.code != SKErrorPaymentCancelled) {
        UALOG(@"Transaction Failed (%d), product: %@", (int)transaction.error.code, transaction.payment.productIdentifier);
        id<UAStoreFrontAlertProtocol> alertHandler = [[[UAStoreFront shared] uiClass] getAlertHandler];
        [alertHandler showPaymentTransactionFailedAlert];
    }

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
    
    [self finishTransaction:transaction];
}

#pragma mark -
#pragma mark Hosted download lifecycle methods

- (void)updateProgress:(SKDownload *)download {
    UAProduct *product = [self productForDownload:download];
    product.progress = download.progress;
}

- (void)downloadFinished:(SKDownload *)download {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *contentPath = download.contentURL.path;
    NSString *destination = [[UAStoreFront shared].downloadManager.downloadDirectory stringByAppendingPathComponent:download.contentIdentifier];

    UAProduct *product = [self productForDownload:download];

    //remove destination path if it alredy exists, so we don't annoy NSFileManager
    if ([fm fileExistsAtPath:destination]) {
        [[NSFileManager defaultManager] removeItemAtPath:destination error:nil];
    }

    NSError *directoryError = nil;

    //copy temporary download directory
    if (![fm copyItemAtPath:contentPath
                      toPath:destination
                     error:&directoryError]) {
        UA_LERR(@"Error copying directory: %@, %d", download.contentURL.path, directoryError.code);
        [self productInstallFailed:product];
        return;
    }

    UA_LINFO(@"Successfully installed %@", download.contentIdentifier);

    [self productInstallSucceeded:product];
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
    self.restoring = NO;
    for (SKPaymentTransaction *transaction in unRestoredTransactions) {
        [self finishTransaction:transaction];
        UAProduct *product = [self productFromTransaction:transaction];
        [product resetStatus];
    }

    RELEASE_SAFELY(unRestoredTransactions);
    UALOG(@"paymentQueue:%@ restoreCompletedTransactionsFailedWithError:%@", queue, error);

}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    UALOG(@"paymentQueueRestoreCompletedTransactionsFinished:%@", queue);
    self.restoring = NO;
    id<UAStoreFrontAlertProtocol> alertHandler = [[[UAStoreFront shared] uiClass] getAlertHandler];
    [alertHandler showConfirmRestoringAlert:[unRestoredTransactions count]
                                   delegate:self approveSelector:@selector(downloadAllRestoredItems)
                         disapproveSelector:@selector(discardAllRestoredItems)];
}

- (void)downloadAllRestoredItems {
    for (SKPaymentTransaction *transaction in unRestoredTransactions) {
        [[UAStoreFront shared].downloadManager verifyTransactionReceipt:transaction];
    }
    RELEASE_SAFELY(unRestoredTransactions);
}

- (void)discardAllRestoredItems {
    for (SKPaymentTransaction *transaction in unRestoredTransactions) {
        [self finishTransaction:transaction];
    }
    RELEASE_SAFELY(unRestoredTransactions);
}

//this is the main entry point for events related to apple-hosted download status.
//be sure to close the associated transaction once the download has passed into a final
//(e.g. canceled/failed/finished) state, but never while the download is still being processed.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads {
    for (SKDownload *download in downloads) {
        switch (download.downloadState) {
            case SKDownloadStateWaiting:
                UA_LTRACE(@"%@: downlaod waiting", download.contentIdentifier);
                break;
            case SKDownloadStateActive:
                UA_LTRACE(@"%@: download active", download.contentIdentifier);
                //this state is set periodically, and can be used to update progress in the UI
                [self updateProgress:download];
                break;
            case SKDownloadStateCancelled:
                UA_LINFO(@"%@: download cancelled", download.contentIdentifier);
                [self productInstallCancelled:[self productForDownload:download]];
                [self finishTransaction:download.transaction];
                break;
            case SKDownloadStateFailed:
                UA_LINFO(@"%@: download failed", download.contentIdentifier);
                [self productInstallFailed:[self productForDownload:download]];
                [self finishTransaction:download.transaction];
                break;
            case SKDownloadStatePaused:
                UA_LINFO(@"%@: download paused", download.contentIdentifier);
                break;
            case SKDownloadStateFinished:
                UA_LINFO(@"%@: download finished", download.contentIdentifier);
                [self downloadFinished:download];
                [self finishTransaction:download.transaction];
                break;
            default:
                break;
        }
    }
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
    self.restoring = YES;
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

#pragma mark -
#pragma mark Transaction Management

- (void)finishTransaction:(SKPaymentTransaction *)transaction {
    
    if (transaction && [[[SKPaymentQueue defaultQueue] transactions] containsObject:transaction]) {
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

- (void)finishUnknownTransaction:(SKPaymentTransaction *)transaction {
    
    if (transaction && [[[SKPaymentQueue defaultQueue] transactions] containsObject:transaction]) {
        
        NSString *identifier = transaction.payment.productIdentifier;
        UAProduct *product = [[UAStoreFront shared].inventory productWithIdentifier:identifier];
        
        Class subscriptionManagerClass = NSClassFromString(@"UASubscriptionManager");
        BOOL subscriptionManagerPresent = subscriptionManagerClass && [subscriptionManagerClass initialized];
        
        // if we have the product or the subscription manager has not been initialized,
        // go ahead an close it.
        // otherwise, let the subscription manager deal with it
        if (product) {
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        } else if (!subscriptionManagerPresent) {
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
    }
    
}

@end
