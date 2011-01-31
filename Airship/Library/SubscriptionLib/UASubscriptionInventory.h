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
#import "UAObservable.h"
#import <StoreKit/StoreKit.h>

@class UAProductInventory;
@class UAContentInventory;
@class UASubscriptionProduct;
@class UASubscriptionContent;
@class UASubscription;
@class UASubscriptionDownloadManager;

@interface UASubscriptionInventory : UAObservable {
    UASubscriptionDownloadManager *downloadManager;
    NSMutableArray *subscriptions;
    NSMutableArray *userSubscriptions;
    NSMutableDictionary *subscriptionDict;
    NSArray *userPurchasingInfo;

    UAProductInventory *products;
    UAContentInventory *contents;

    BOOL userPurchasingInfoLoaded;
    BOOL productsLoaded;
    BOOL contentsLoaded;
    BOOL hasLoaded;

    BOOL has_active_subscriptions;
    NSDate *serverDate;
}

@property (nonatomic, assign, readonly) BOOL hasLoaded;
@property (nonatomic, retain, readonly) NSMutableArray *userSubscriptions;
@property (nonatomic, retain, readonly) NSMutableArray *subscriptions;
@property (nonatomic, retain) NSDate *serverDate;

- (void)loadInventory;
- (void)loadProducts;
- (void)loadPurchases;

- (void)purchase:(UASubscriptionProduct *)product;
- (void)download:(UASubscriptionContent *)content;
- (void)checkDownloading:(UASubscriptionContent *)content;

- (UASubscription *)subscriptionForKey:(NSString *)subscriptionKey;
- (UASubscription *)subscriptionForProduct:(UASubscriptionProduct *)product;
- (UASubscription *)subscriptionForContent:(UASubscriptionContent *)content;

- (void)createSubscription;
- (void)createUserSubscription;
- (void)loadUserPurchasingInfo;

- (BOOL)containsProduct:(NSString *)productID;
- (UASubscriptionProduct *)productForKey:(NSString *)productKey;

- (void)subscriptionTransctionDidComplete:(SKPaymentTransaction *)transaction;

- (void)productInventoryUpdated;
- (void)contentInventoryUpdated;

@end