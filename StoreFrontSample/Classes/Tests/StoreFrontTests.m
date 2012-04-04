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

#import "StoreFrontTests.h"

@implementation StoreFrontTests

UAInventoryStatus inventoryLoadStatus;

- (BOOL)shouldRunOnMainThread {
    // By default NO, but if you have a UI test or test dependent on running on the main thread return YES
    return YES;
}

- (void)setUpClass {
    inventoryLoadStatus = UAInventoryStatusUnloaded;
    [self mock:[UAStoreFront class] method:@selector(initProperties) withMethod:@selector(initProperties_with_dummy_skobserver)];
    [self mock:[UAStoreFrontDownloadManager class] method:@selector(resumePendingProducts) withMethod:@selector(doNothing)];
    [UAStoreFront registerObserver:self];
    skObserver = (MockedUAStoreKitObserver *)[UAStoreFront shared].sfObserver;
    [UAStoreFront loadInventory];
}

- (void)tearDownClass {
    [UAStoreFront unregisterObserver:self];
    [[UAStoreFront shared] forceRelease];
}

- (void)setUp {
    [skObserver reset];
}

- (void)tearDown {
    [skObserver finishTransaction:skObserver.currTransaction];
    [skObserver reset];
}

#pragma mark -
#pragma mark Observer callbacks

- (void)inventoryStatusChanged:(NSNumber *)status {
    inventoryLoadStatus = [status intValue];
}

#pragma mark -
#pragma mark Test purchase a invalid product

- (BOOL)checkTransactionCompletedWithState:(SKPaymentTransactionState)state {
    SKPaymentTransaction *transaction = skObserver.currTransaction;
    if (transaction) {
        return skObserver.currTransactionDidCompleted && (transaction.transactionState == state);
    } else {
        return NO;
    }
}

- (BOOL)checkTransactionFailed {
    return [self checkTransactionCompletedWithState:SKPaymentTransactionStateFailed];
}

- (BOOL)checkTransactionPurchased {
    return [self checkTransactionCompletedWithState:SKPaymentTransactionStatePurchased];
}

- (void)testPurchaseDummyProduct {
    GHAssertEquals([SKPaymentQueue canMakePayments], YES, @"Should enable payment!");

    [UAStoreFront purchase:@"urban_invalid_product"];
    BOOL timeout = [self spinRunThreadWithTimeOut:60
                                finishedCheckFunc:@selector(checkTransactionFailed)
                                 processingString:@"Waiting for payment transction to finish..."];
    GHAssertEquals(timeout, NO, @"Test purchase a dummy product failed! timeout");
    SKPaymentTransaction *transaction = skObserver.currTransaction;
    GHAssertEquals(transaction.transactionState, SKPaymentTransactionStateFailed,
                 [NSString stringWithFormat:@"Test purchase a dummy product failed! transactionState=%d.", transaction.transactionState]);
}

- (void)_testPurchaseProduct:(NSString*)productID
        expectVerifyTransactionCallTimes:(int)expectVerifyTransactionCallTimes
        expectVerifyProductCallTimes:(int)expectVerifyProductCallTimes {
    GHAssertEquals([SKPaymentQueue canMakePayments], YES, @"Should enable payment!");

    // clean previous calls
    [UAStoreFrontDownloadManager removeAllCalls];

    // insure that we have a valid product with id 'aachlorine' on apple store
    [self mock:[UAStoreFrontDownloadManager class] method:@selector(verifyTransaction:) withMethod:@selector(record_call_and_continue_verifyTransaction:)];
    [self mock:[UAStoreFrontDownloadManager class] method:@selector(verifyProduct:) withMethod:@selector(record_call_verifyProduct:)];
    
    [UAStoreFrontDownloadManager removeAllCalls];// in case run the tests many times
    [skObserver payForProduct:productID];
    
    BOOL timeout = [self spinRunThreadWithTimeOut:60
                                finishedCheckFunc:@selector(checkTransactionPurchased)
                                 processingString:@"Waiting for payment transction to finish..."];
    GHAssertEquals(timeout, NO, @"Test purchase product failed! timeout");
    // now we have a valid transaction object, then call downloadManager to download it
    SKPaymentTransaction *transaction = skObserver.currTransaction;
    [[UAStoreFront shared].downloadManager downloadIfValid:transaction];
    
    // assert the verifyProduct method been invoked
    int verifyTransactionCallTimes = [UAStoreFrontDownloadManager getCallTimes:@selector(verifyTransaction:)];
    int verifyProductCallTimes = [UAStoreFrontDownloadManager getCallTimes:@selector(verifyProduct:)];
    GHAssertEquals(expectVerifyTransactionCallTimes, verifyTransactionCallTimes,
                   [NSString stringWithFormat:@"Test purchase product failed! verifyTransactionCallTimes=%d.", verifyTransactionCallTimes]);
    GHAssertEquals(expectVerifyProductCallTimes, verifyProductCallTimes,
                   [NSString stringWithFormat:@"Test purchase product failed! verifyProductCallTimes=%d.", verifyProductCallTimes]);
}

- (void)testPurchaseValidProduct {
    [self _testPurchaseProduct:@"aachlorine"
        expectVerifyTransactionCallTimes:1 expectVerifyProductCallTimes:1];
}

- (void)testPurchaseNotExistProduct {
    // mock the inventory hasProductWithIdentifier method to always return NO, which means
    // all products are no-longer-exist
    [self mock:[UAInventory class] method:@selector(hasProductWithIdentifier:) withMethod:@selector(returnNO:)];

    [self _testPurchaseProduct:@"mercury_nonc"
        expectVerifyTransactionCallTimes:1 expectVerifyProductCallTimes:0];
}

@end


@implementation UAStoreFrontDownloadManager(Mocked)

- (void)record_call_and_continue_verifyTransaction:(SKPaymentTransaction*)transaction {
    [[self class] recordCallSelector:@selector(verifyTransaction:)
                            withArgs:[NSArray arrayWithObjects:transaction, nil]];
    [self record_call_and_continue_verifyTransaction:transaction];
}
// for test, we don't post a request to verify, just record this call
- (void)record_call_verifyProduct:(UAProduct*)product {
    [[self class] recordCallSelector:@selector(verifyProduct:)
                            withArgs:[NSArray arrayWithObjects:product, nil]];
    return;
}
@end
