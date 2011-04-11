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

#import <StoreKit/StoreKit.h>
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAStoreFrontDelegate.h"
#import "UAStoreFrontAlertProtocol.h"

#define STOREFRONT_UI_CLASS @"UAStoreFrontUI"

UIKIT_EXTERN NSString *const UAContentsDisplayOrderTitle;
UIKIT_EXTERN NSString *const UAContentsDisplayOrderID;
UIKIT_EXTERN NSString *const UAContentsDisplayOrderPrice;

typedef enum {
    UAInventoryStatusUnloaded = 0,
    UAInventoryStatusPurchaseDisabled,
    UAInventoryStatusDownloading,
    UAInventoryStatusApple,
    UAInventoryStatusLoaded,
    UAInventoryStatusFailed,
} UAInventoryStatus;

typedef enum {
    ProductTypeAll = 0,
    ProductTypeInstalled = 1,
    ProductTypeUpdated = 2,
    ProductTypeOrigin = 10
} ProductType;

UA_VERSION_INTERFACE(StoreFrontVersion)

@protocol UAStoreFrontUIProtocol
@required
+ (void)quitStoreFront;
+ (void)displayStoreFront:(UIViewController *)viewController animated:(BOOL)animated;
+ (id<UAStoreFrontAlertProtocol>)getAlertHandler;
@end

@protocol UAStoreFrontObserverProtocol
@optional
// will notify this method if restoring status changed
- (void)restoreStatusChanged:(NSNumber*)inRestoring;
// will notify this method if inventory groups updated
- (void)inventoryGroupUpdated;
// will notify this method if inventory loading status changed
- (void)inventoryStatusChanged:(NSNumber *)status;
// will notify this method if anyone of products in the inventory been changed.
// always can be used to control inventory level ui elements (not related to a
// specified product), such as 'restore all' button
- (void)inventoryProductsChanged:(UAProductStatus*)status;
@end

@protocol UAProductObserverProtocol
@optional
- (void)productStatusChanged:(NSNumber*)status;
- (void)productProgressChanged:(NSNumber*)progress;
@end

@class UAInventory;
@class UAStoreKitObserver;
@class UAStoreFrontDownloadManager;

@interface UAStoreFront : NSObject {
    UAStoreKitObserver* sfObserver;
    UAInventory* inventory;
    UAStoreFrontDownloadManager* downloadManager;

    NSObject<UAStoreFrontDelegate> *delegate;
    NSMutableDictionary* purchaseReceipts;
}

@property (nonatomic, retain, readonly) UAStoreKitObserver* sfObserver;
@property (nonatomic, retain, readonly) UAStoreFrontDownloadManager* downloadManager;
@property (nonatomic, assign) NSObject<UAStoreFrontDelegate> *delegate;
@property (nonatomic, retain) UAInventory* inventory;
@property (nonatomic, retain) NSMutableDictionary* purchaseReceipts;

SINGLETON_INTERFACE(UAStoreFront)

+ (void)useCustomUI:(Class)customUIClass;
+ (void)quitStoreFront;

/*
 Present the store front as modalViewController over viewController
 */
+ (void)displayStoreFront:(UIViewController *)viewController animated:(BOOL)animated;
+ (void)displayStoreFront:(UIViewController *)viewController withProductID:(NSString *)ID animated:(BOOL)animated;

/*
 Set the displaying order of the product items in content tab
 Default is order by product ID, descending
 */
+ (void)setOrderBy:(NSString *)key;
+ (void)setOrderBy:(NSString *)key ascending:(BOOL)ascending;

/*
 Directly purchase a specific product
 */
+ (void)purchase:(NSString *)productIdentifier;
+ (void)land;

/*
 inverntory/payment observer registration
 */
+ (void)registerObserver:(id)observer;
+ (void)unregisterObserver:(id)observer;

- (void)addReceipt:(UAProduct *)product;
- (BOOL)hasReceipt:(UAProduct *)product;
- (BOOL)directoryExistsAtPath:(NSString *)path orOldPath:(NSString *)oldPath;
+ (BOOL)setDownloadDirectory:(NSString *)path;
+ (BOOL)setDownloadDirectory:(NSString *)path withProductIDSubdir:(BOOL)makeSubdir;
- (Class)uiClass;

/*
 load inventory
 */
+ (void)loadInventory;
+ (void)resetAndLoadInventory;
+ (void)reloadInventoryIfFailed;

/*
 operations on products
 */
+ (NSArray*)productsForType:(ProductType)type;
+ (void)updateAllProducts;
+ (void)restoreAllProducts;

@end
