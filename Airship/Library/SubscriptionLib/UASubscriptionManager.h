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

#import "UAGlobal.h"
#import "UAUser.h"
#import "UASubscriptionProduct.h"

#define SUBSCRIPTION_UI_CLASS @"UASubscriptionUI"

UA_VERSION_INTERFACE(SubscriptionVersion)

@class UASubscriptionObserver;
@class UASubscriptionInventory;
@class UASubscriptionContent;

@protocol UASubscriptionUIProtocol
+ (void)displaySubscription:(UIViewController *)viewController
                   animated:(BOOL)animated;
+ (void)hideSubscription;
@end

/*
 * Important:
 * Since subscription and its products are created only once,
 * so same instance during one execution.
 * But contents will be reloaded once new product is purchased,
 * so contents' instance will be changed
 */
@protocol UASubscriptionManagerObserver <NSObject>
@optional
- (void)subscriptionWillEnterForeground;
- (void)subscriptionWillEnterBackground;

- (void)subscriptionsUpdated:(NSArray *)subscriptions;
- (void)userSubscriptionsUpdated:(NSArray *)userSubscritions;
- (void)userSubscriptionsUpdateFailed;//TODO: stub - will indicate inventory failure reason (storekit/ua connectivity)

- (void)downloadContentFinished:(UASubscriptionContent *)content;
- (void)downloadContentFailed:(UASubscriptionContent *)content;

- (void)purchaseProductFinished:(UASubscriptionProduct *)product; //TODO: stub
- (void)purchaseProductFailed:(UASubscriptionProduct *)product; //TODO: stub - will indicate reason (storekit/ua connectivity)

/**
 * This method is called when a restore process completes without error.
 *
 * @param productsRestored An array of the products for which receipts were
 *   found, nil if no autorenewables were found.
 *
 */
- (void)restoreAutorenewablesFinished:(NSArray *)productsRestored;

/**
 * This method is called when a restore fails due to a StoreKit error.
 */
- (void)restoreAutorenewablesFailed;

/**
 * This is called when a specific autorenewable receipt verification fails due
 * to an invalid receipt or network issues. A success message may still follow
 * for other products.
 * 
 * @param product The product that failed during receipt verification.
 */
- (void)restoreAutorenewableProductFailed:(UASubscriptionProduct *)product;
@end


@interface UASubscriptionManager : UAObservable {
    UASubscriptionInventory *inventory;
    UASubscriptionObserver *transactionObserver;
    UASubscriptionProduct *pendingProduct;
}

// public
@property (retain, readonly) UASubscriptionInventory *inventory;
@property (retain, nonatomic) UASubscriptionProduct *pendingProduct;

SINGLETON_INTERFACE(UASubscriptionManager)

- (Class)uiClass;
+ (void)useCustomUI:(Class)customUIClass;
+ (void)displaySubscription:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)hideSubscription;
+ (void)land;

// private
@property (retain, readonly) UASubscriptionObserver *transactionObserver;

- (void)loadSubscription;
- (void)enterForeground;
- (void)enterBackground;
- (void)subscriptionWillEnterForeground;
- (void)subscriptionWillEnterBackground;
- (void)subscriptionsUpdated:(NSArray *)subscriptions;
- (void)userSubscriptionsUpdated:(NSArray *)userSubscritions;
- (void)purchaseProductFinished:(UASubscriptionProduct *)product;
- (void)downloadContentFinished:(UASubscriptionContent *)content;
- (void)downloadContentFailed:(UASubscriptionContent *)content;
- (void)restoreAutorenewablesFinished:(NSArray *)productsRestored;
- (void)restoreAutorenewableProductFailed:(UASubscriptionProduct *)product;
- (void)restoreAutorenewablesFailed;

- (void)purchase:(UASubscriptionProduct *)product;
- (void)setPendingSubscription:(UASubscriptionProduct *)product;
- (void)purchasePendingSubscription;

- (void)restoreAutorenewables;

@end
