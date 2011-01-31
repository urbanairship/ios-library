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

#import <Foundation/Foundation.h>

@class UASubscriptionProduct;
@class UASubscriptionContent;

@interface UASubscription : NSObject {
    NSString *key;
    NSString *name;
    BOOL subscribed;
    NSMutableArray *products;
    // copies of products that have been purchased
    NSMutableArray *purchasedProducts;
    NSMutableArray *availableContents;
    NSMutableArray *downloadedContents;
    NSMutableArray *undownloadedContents;
}

@property (nonatomic, retain, readonly) NSString *key;
@property (nonatomic, retain, readonly) NSString *name;
@property (nonatomic, assign, readonly) BOOL subscribed;
@property (nonatomic, retain, readonly) NSMutableArray *products;
@property (nonatomic, retain, readonly) NSMutableArray *purchasedProducts;
@property (nonatomic, retain, readonly) NSMutableArray *availableContents;
@property (nonatomic, retain, readonly) NSMutableArray *downloadedContents;
@property (nonatomic, retain, readonly) NSMutableArray *undownloadedContents;

- (id)initWithKey:(NSString *)aKey name:(NSString *)aName;
- (void)setProductsWithArray:(NSArray *)productArray;
- (void)setPurchasedProductsWithArray:(NSArray *)infos;
- (void)setContentsWithArray:(NSArray *)contents;
- (void)filterDownloadedContents;

@end
