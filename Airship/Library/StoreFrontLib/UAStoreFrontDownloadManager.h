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

#import <Foundation/Foundation.h>

#import "UADownloadManager.h"

@class UAProduct;
@class SKPaymentTransaction;

@interface UAStoreFrontDownloadManager : NSObject <UADownloadManagerDelegate> {
  @private
    NSMutableDictionary *pendingProducts;
    NSMutableDictionary *decompressingProducts;
    NSString *downloadDirectory;
    UADownloadManager *downloadManager;
    BOOL createProductIDSubdir;
}
@property (nonatomic, copy) NSString *downloadDirectory;
@property (nonatomic, assign) BOOL createProductIDSubdir;

//load the pending products dictionary from kPendingProductsFile
- (void)loadPendingProducts;
- (BOOL)hasPendingProduct:(UAProduct *)product;
- (void)resumePendingProducts;

//load the decompressing products dictionary from kDecompressingProductsFile
- (void)loadDecompressingProducts;
- (BOOL)hasDecompressingProduct:(UAProduct *)product;
- (void)resumeDecompressingProducts;

- (void)downloadPurchasedProduct:(UAProduct *)product;
- (void)verifyTransactionReceipt:(SKPaymentTransaction *)transaction;

- (void)downloadDidFail:(UADownloadContent *)downloadContent;
@end
