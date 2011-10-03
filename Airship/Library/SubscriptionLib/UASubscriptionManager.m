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

#import "UASubscriptionManager.h"

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import "UASubscriptionObserver.h"
#import "UAProductInventory.h"
#import "UAContentInventory.h"
#import "UASubscriptionInventory.h"
#import "UASubscriptionProduct.h"
#import "UASubscriptionDownloadManager.h"

#import "UAUser.h"

// Weak link to this notification since it doesn't exist in iOS 3.x
UIKIT_EXTERN NSString* const UIApplicationWillEnterForegroundNotification __attribute__((weak_import));
UIKIT_EXTERN NSString* const UIApplicationDidEnterBackgroundNotification __attribute__((weak_import));

UA_VERSION_IMPLEMENTATION(SubscriptionVersion, UA_VERSION)

// Subscription error messages
NSString * const UASubscriptionTransactionErrorDomain = @"UASubscriptionTransactionErrorDomain";
NSString * const UASubscriptionReceiptVerificationFailure = @"UA Subscription Receipt is Invalid";

NSString * const UASubscriptionRequestErrorDomain = @"UASubscriptionRequestErrorDomain";

NSString * const UASubscriptionPurchaseInventoryFailure = @"UA Subscription Purchases Failed to Load";
NSString * const UASubscriptionContentInventoryFailure = @"UA Subscription Content Inventory Failed to Load";
NSString * const UASubscriptionProductInventoryFailure = @"UA Subscription Product Inventory Failed to Load";

@implementation UASubscriptionManager
@synthesize transactionObserver;
@synthesize inventory;
@synthesize pendingProduct;
@synthesize downloadManager;

SINGLETON_IMPLEMENTATION(UASubscriptionManager)

+ (BOOL)initialized {
    return g_sharedUASubscriptionManager ? YES : NO;
}

#pragma mark -
#pragma mark Custom UI

static Class _uiClass;

- (Class)uiClass {
    if (!_uiClass) {
        _uiClass = NSClassFromString(SUBSCRIPTION_UI_CLASS);
    }
    
    if (_uiClass == nil) {
        UALOG(@"Subscription UI class not found.");
    }
	
    return _uiClass;
}

#pragma mark -
#pragma mark Open APIs, set custom ui

+ (void)useCustomUI:(Class)customUIClass {
    _uiClass = customUIClass;
}


#pragma mark Class Methods

+ (void)displaySubscription:(UIViewController *)viewController animated:(BOOL)animated {
    [[[UASubscriptionManager shared] uiClass] displaySubscription:viewController animated:animated];
}

+ (void)hideSubscription {
    [[[UASubscriptionManager shared] uiClass] performSelector:@selector(hideSubscription)];
}

+ (void)land {
	[[UAUser defaultUser] removeObserver:self];
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:[UASubscriptionManager shared].transactionObserver];
}

#pragma mark -
#pragma mark Custom DL Directory Class Methods


+ (BOOL)setDownloadDirectory:(NSString *)path {
    return [self setDownloadDirectory:path withProductIDSubdir:YES];
}


+ (BOOL)setDownloadDirectory:(NSString *)path withProductIDSubdir:(BOOL)makeSubdir {
    
    BOOL success = YES;
    
    // It'll be used default dir when path is nil.
    if (path == nil) {
        // The default is created in sfObserver's init
        UALOG(@"Using Default Download Directory: %@", [UASubscriptionManager shared].downloadManager.downloadDirectory);
        return success;
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        success = [[NSFileManager defaultManager] createDirectoryAtPath:path
                                            withIntermediateDirectories:YES
                                                             attributes:nil
                                                                  error:nil];
    }
    
    if (success) {
        [UASubscriptionManager shared].downloadManager.downloadDirectory = path;
        [UASubscriptionManager shared].downloadManager.createProductIDSubdir = makeSubdir;
        
        UALOG(@"New Download Directory: %@", [UASubscriptionManager shared].downloadManager.downloadDirectory);
    }
    
    return success;
}

#pragma mark Lifecycle Methods

- (id)init {
    if (self = [super init]) {

IF_IOS4_OR_GREATER(
            // Register notification to reload when moving from background to foreground
            if (&UIApplicationWillEnterForegroundNotification != NULL) {
				
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(enterForeground)
                                                             name:UIApplicationWillEnterForegroundNotification
                                                           object:nil];
            }
				   
			if (&UIApplicationDidEnterBackgroundNotification != NULL) {
										  
				[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(enterBackground)
															 name:UIApplicationDidEnterBackgroundNotification
														   object:nil];
			}
									
);

        //Make sure the default ua directory exists, we use it for storing
        //various bits of data like download history, image cache
        BOOL uaExists = [[NSFileManager defaultManager] fileExistsAtPath:kUADirectory];
        if(!uaExists) {
            [[NSFileManager defaultManager] createDirectoryAtPath:kUADirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        //Set up default download directory
        if (![[NSFileManager defaultManager] fileExistsAtPath:kUADownloadDirectory]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:kUADownloadDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }

        transactionObserver = [[UASubscriptionObserver alloc] init];
        inventory = [[UASubscriptionInventory alloc] init];
        downloadManager = [[UASubscriptionDownloadManager alloc] init];
		
		// Check to see if the defaultUser is good to go, if it is we can load our subscription data
		if([[UAUser defaultUser] defaultUserCreated]) {
			[self loadSubscription];
		} 
		
		[[UAUser defaultUser] addObserver:self];
    }
    return self;
}

- (void)dealloc {
    RELEASE_SAFELY(pendingProduct);
    RELEASE_SAFELY(inventory);
    RELEASE_SAFELY(transactionObserver);
    self.downloadManager = nil;
    [super dealloc];
}

#pragma mark Load Subscription

- (void)loadSubscription {
    [inventory loadInventory];
}

#pragma mark Multitask Supporting

- (void)enterForeground {
    // reload inventory
    if (inventory.hasLoaded) {
        [self loadSubscription];
    }
    [self subscriptionWillEnterForeground];
}

- (void) enterBackground {
	[self subscriptionWillEnterBackground];
}

#pragma mark -
#pragma mark Deliver Notifications for Critical Logic Events

- (void)subscriptionWillEnterForeground {
    [self notifyObservers:@selector(subscriptionWillEnterForeground)];
}
	 
- (void)subscriptionWillEnterBackground {
	[self notifyObservers:@selector(subscriptionWillEnterBackground)];
}

- (void)subscriptionsUpdated:(NSArray *)subscriptions {
    [self notifyObservers:@selector(subscriptionsUpdated:) withObject:subscriptions];
}

- (void)userSubscriptionsUpdated:(NSArray *)userSubscriptions {
    [self notifyObservers:@selector(userSubscriptionsUpdated:) withObject:userSubscriptions];
}

- (void)inventoryUpdateFailedWithError:(NSError *)error {
    [self notifyObservers:@selector(inventoryUpdateFailedWithError:) withObject:error];
}

- (void)purchaseProductFinished:(UASubscriptionProduct *)product {
    [self notifyObservers:@selector(purchaseProductFinished:) withObject:product];
}

- (void)purchaseProductFailed:(UASubscriptionProduct *)product withError:(NSError *)error {
    [self notifyObservers:@selector(purchaseProductFailed:withError:) withObject:product withObject:error];
}

- (void)downloadContentFinished:(UASubscriptionContent *)content {
    [self notifyObservers:@selector(downloadContentFinished:) withObject:content];
}

- (void)downloadContentFailed:(UASubscriptionContent *)content {
    [self notifyObservers:@selector(downloadContentFailed:) withObject:content];
}

- (void)restoreAutorenewablesFinished:(NSArray *)productsRestored {
    [self notifyObservers:@selector(restoreAutorenewablesFinished:) withObject:productsRestored];
}

- (void)restoreAutorenewableProductFailed:(UASubscriptionProduct *)product {
    [self notifyObservers:@selector(restoreAutorenewableProductFailed:) withObject:product];
}

- (void)restoreAutorenewablesFailedWithError:(NSError *)error {
    [self notifyObservers:@selector(restoreAutorenewablesFailedWithError:) withObject:error];
}

#pragma mark -
#pragma mark Purchase

- (void)purchase:(UASubscriptionProduct *)product {
    
    [[UASubscriptionManager shared].inventory purchase:product];

}

- (void)purchaseProductWithId:(NSString *)productId {
    UASubscriptionProduct *product = [[UASubscriptionManager shared].inventory productForKey:productId];
    [self purchase:product];
}

- (void)setPendingSubscription:(UASubscriptionProduct *)product {
    self.pendingProduct = product;
}

- (void)purchasePendingSubscription {
    
    if (!pendingProduct) {
        return;
    }

    [[UASubscriptionManager shared].inventory purchase:pendingProduct];
    self.pendingProduct = nil;

}

#pragma mark UAUserObserver

- (void)userUpdated {
    UALOG(@"Received userUpdated - (re)load Subscription data");
	if([[UAUser defaultUser] defaultUserCreated]) {
		[self loadSubscription];
	}
}

- (void)userRecoveryFinished {
    UALOG(@"Received userRecoveryFinished - (re)load Subscription data");
	[self loadSubscription];
}

#pragma mark -
#pragma mark Restore Autorenewable Subscriptions

- (void)restoreAutorenewables {
    [transactionObserver restoreAutorenewables];
}
@end
