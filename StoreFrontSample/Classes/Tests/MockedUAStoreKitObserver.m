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

#import "MockedUAStoreKitObserver.h"


@implementation MockedUAStoreKitObserver

@synthesize currProductID;
@synthesize currTransaction;
@synthesize currTransactionDidCompleted;

- (void)finishTransaction:(SKPaymentTransaction *)transaction {
    if (transaction) {
        UALOG(@"finishTransaction: %@ for product : %@", transaction, transaction.payment.productIdentifier);
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

- (void)startTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"startTransaction: %@ for product : %@", transaction, transaction.payment.productIdentifier);
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"completeTransaction : %@ for product : %@", transaction, transaction.payment.productIdentifier);
    if (![currProductID isEqualToString:transaction.payment.productIdentifier]
        || currTransaction) {
        [self finishTransaction:transaction];
        return;
    }
    currTransactionDidCompleted = YES;
    currTransaction = transaction;
    //[super completeTransaction:transaction];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    UALOG(@"failedTransaction : %@ for product : %@ with errorcode=%d error=%@",
          transaction, transaction.payment.productIdentifier,
          [transaction.error code], transaction.error);
    if (![currProductID isEqualToString:transaction.payment.productIdentifier]
        || currTransaction) {
        [self finishTransaction:transaction];
        return;
    }
    UALOG(@"failedTransaction");
    currTransactionDidCompleted = YES;
    currTransaction = transaction;
    //[self transactionDidFinished:transaction];
}

- (void)payForProduct:(NSString *)productIdentifier {
    currProductID = productIdentifier;
    [super payForProduct:productIdentifier];
}

- (void)reset {
    currProductID = nil;
    currTransaction = nil;
    currTransactionDidCompleted = NO;
}

@end
