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
#import "UASubscriptionObserver.h"
#import <StoreKit/StoreKit.h>
#import "UAProductInventory.h"
#import "UAContentInventory.h"
#import "UASubscriptionInventory.h"
#import "UASubscriptionProduct.h"

// Weak link to this notification since it doesn't exist in iOS 3.x
UIKIT_EXTERN NSString* const UIApplicationWillEnterForegroundNotification __attribute__((weak_import));
UIKIT_EXTERN NSString* const UIApplicationDidEnterBackgroundNotification __attribute__((weak_import));

UA_VERSION_IMPLEMENTATION(SubscriptionVersion, UA_VERSION)

@implementation UASubscriptionManager
@synthesize transactionObserver;
@synthesize inventory;
@synthesize pendingProduct;

SINGLETON_IMPLEMENTATION(UASubscriptionManager)

#pragma mark -
#pragma mark Custom UI

static Class _uiClass;

- (Class)uiClass {
    if (!_uiClass) {
        _uiClass = NSClassFromString(SUBSCRIPTION_UI_CLASS);
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

- (void)purchaseProductFinished:(UASubscriptionProduct *)product {
    [self notifyObservers:@selector(purchaseProductFinished:) withObject:product];
}

- (void)downloadContentFinished:(UASubscriptionContent *)content {
    [self notifyObservers:@selector(downloadContentFinished:) withObject:content];
}

- (void)downloadContentFailed:(UASubscriptionContent *)content {
    [self notifyObservers:@selector(downloadContentFailed:) withObject:content];
}

#pragma mark -
#pragma mark Purchase

- (void)purchase:(UASubscriptionProduct *)product {
    
    [[UASubscriptionManager shared].inventory purchase:product];

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

@end
