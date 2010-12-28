/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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

#import "UAInventory.h"
#import "UAStoreKitObserver.h"
#import "UAProduct.h"
#import "UAStoreFrontDownloadManager.h"

#import "UA_SBJSON.h"
#import "UA_Reachability.h"
#import "UA_ASIHTTPRequest.h"

#define MAX_RELOAD_TIME 5

NSString *const UAContentsDisplayOrderTitle = @"title";
NSString *const UAContentsDisplayOrderID = @"productIdentifier";
NSString *const UAContentsDisplayOrderPrice = @"priceNumber";


@implementation UAInventory

@synthesize status;
@synthesize orderBy;
@synthesize purchasingProductIdentifier;

#pragma mark -
#pragma mark Memory management

-(void)dealloc {
    RELEASE_SAFELY(purchasingProductIdentifier);
    RELEASE_SAFELY(products);
    RELEASE_SAFELY(keys);
    RELEASE_SAFELY(sortedProducts);
    RELEASE_SAFELY(updatedProducts);
    RELEASE_SAFELY(installedProducts);
    RELEASE_SAFELY(hostReach);
    RELEASE_SAFELY(orderBy);
    [super dealloc];
}

- (UAInventory*)init {
    if (self = [super init]) {
        products = [[NSMutableDictionary alloc] init];
        keys = [[NSMutableArray alloc] init];
        sortedProducts = [[NSMutableArray alloc] init];
        updatedProducts = [[NSMutableArray alloc] init];
        installedProducts = [[NSMutableArray alloc] init];

        self.orderBy = UAContentsDisplayOrderID;
        orderAscending = NO;

        hostReach = [[UA_Reachability reachabilityForInternetConnection] retain];
        reloadCount = 0;

        self.status = UAInventoryStatusUnloaded;
    }
    return self;
}

#pragma mark -
#pragma mark Product management

- (NSArray *)productsForType:(ProductType)type {
    if (type == ProductTypeAll) {
        return sortedProducts;
    } else if (type == ProductTypeInstalled) {
        return installedProducts;
    } else if (type == ProductTypeUpdated) {
        return updatedProducts;
    } else if (type == ProductTypeOrigin) {
        return [products allValues];
    }
    return nil;
}

- (void)updateKeys {
    [keys setArray:[products allKeys]];
    [keys sortUsingSelector:@selector(compare:)];
}

- (UAProduct*)productWithIdentifier:(NSString*)productId {
    return [products objectForKey:productId];
}

- (BOOL)hasProductWithIdentifier:(NSString*)productId {
    return [keys containsObject:productId];
}

- (void)addProduct:(UAProduct*)product {
    [products setObject:product forKey:product.productIdentifier];
    [self updateKeys];

    // If this method will be used after inventory is loaded, then may need to
    // add two following statements
    //[self sortInventory];
    //[self groupInventory];
}

- (void)removeProduct:(NSString*)productId {
    [products removeObjectForKey:productId];
    [self updateKeys];

    // If this method will be used after inventory is loaded, then may need to
    // add two following statements
    //[self sortInventory];
    //[self groupInventory];
}

- (UAProduct*)productAtIndex:(int)index {
    return [products objectForKey:[keys objectAtIndex: index]];
}

#pragma mark -
#pragma mark Load/Reload inventory from ua server

- (void)loadInventory {

    if ([SKPaymentQueue canMakePayments] == NO) {
        UALOG(@"payments disabled");
        self.status = UAInventoryStatusPurchaseDisabled;
        return;
    }
    UALOG(@"payments enabled");

    self.status = UAInventoryStatusDownloading;

    // listen on network changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hostReachStatusChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];

    [products removeAllObjects];
    [keys removeAllObjects];
    [updatedProducts removeAllObjects];
    [installedProducts removeAllObjects];

    [sortedProducts release];
    sortedProducts = [[NSMutableArray alloc] init];

    NSString *urlString = [NSString stringWithFormat: @"%@%@", [[UAirship shared] server], @"/api/app/content/"];
    NSURL *url = [NSURL URLWithString: urlString];

    UA_ASIHTTPRequest *inventoryRequest = [UA_ASIHTTPRequest requestWithURL:url];
    inventoryRequest.username = [[UAirship shared] appId];
    inventoryRequest.password = [[UAirship shared] appSecret];

    [inventoryRequest setDelegate:self];
    [inventoryRequest setTimeOutSeconds: 60];
    [inventoryRequest setDidFinishSelector: @selector(loadInventoryFinished:)];
    [inventoryRequest setDidFailSelector: @selector(loadInventoryFailed:)];

    [inventoryRequest startAsynchronous];
}

- (void)loadInventoryFinished:(UA_ASIHTTPRequest *)request {
    UALOG(@"inventory string: %@",[request responseString]);
    UALOG(@"response header: %@", request.responseHeaders);

    NSString *responseString = [request responseString];
    UA_SBJsonParser *parser = [UA_SBJsonParser new];
    NSArray* tmpInv = [parser objectWithString: responseString];
    [parser release];

    NSMutableSet* productIdentifiers = [[NSMutableSet alloc] initWithCapacity: 3];
    for(NSDictionary *item in tmpInv) {
        UAProduct *product = [UAProduct productFromDictionary:item];
        [self addProduct:product];
        [productIdentifiers addObject:product.productIdentifier];
    }

    self.status = UAInventoryStatusApple;

    // must be released in productsRequest:didReceiveResponse:
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers: productIdentifiers];
    productsRequest.delegate = self;
    [productsRequest start];

    [productIdentifiers release];
}

// For loadInventoryFinished:
- (void)loadInventoryFailed:(UA_ASIHTTPRequest *)request {
    NSError *error = [request error];
    UALOG(@"Connection ERROR: NSError query result: %@", error);
    self.status = UAInventoryStatusFailed;
    [self reloadInventory];
}

- (void)reloadInventory {
    // Will keep reloaing Inventory if network is OK but server return with error
    if ([hostReach currentReachabilityStatus] != NotReachable) {
        //limit attempt times
        if (reloadCount <= MAX_RELOAD_TIME) {
            reloadCount++;
            [self loadInventory];
        }
    } else {
        [hostReach startNotifier];
    }
}

- (void)resetReloadCount {
    reloadCount = 0;
}

#pragma mark -
#pragma mark Load products info from apple

// For productsRequest:didReceiveResponse:
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    UALOG(@"Connection to Apple server ERROR: NSError query result: %@", error);
    self.status = UAInventoryStatusFailed;
    [self reloadInventory];

    RELEASE_SAFELY(request);
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    UAProduct *uaitem = nil;
    for(SKProduct *skitem in response.products) {
        uaitem = [products objectForKey: skitem.productIdentifier];
        if(uaitem != nil && uaitem.isFree != YES) {
            uaitem.title = [skitem localizedTitle];
            uaitem.productDescription = [skitem localizedDescription];
            NSString* localizedPrice = [UAInventory localizedPrice: skitem];
            uaitem.price = localizedPrice;
            uaitem.priceNumber = skitem.price;
        }
    }

    for(NSString *invalid in response.invalidProductIdentifiers) {
        UAProduct* product = [self productWithIdentifier: invalid];
        if(!product.isFree) {
            UALOG(@"INVALID PRODUCT ID: %@", invalid);
            [self removeProduct:invalid];
        }
    }

    [hostReach stopNotifier];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self sortInventory];
    [self groupInventory];
    self.status = UAInventoryStatusLoaded;

    // TODO: see if observer added immediately
    if (purchasingProductIdentifier) {
        [self purchase:purchasingProductIdentifier];
        self.purchasingProductIdentifier = nil;
    }

    RELEASE_SAFELY(request);
}

#pragma mark -
#pragma mark Sort/Group inventory

- (void)groupInventory {
    UALOG(@"==== groupInventory ====");

    [updatedProducts removeAllObjects];
    [installedProducts removeAllObjects];

    for (UAProduct *product in sortedProducts) {
        if (product.status == UAProductStatusHasUpdate)
            [updatedProducts addObject:product];

        if (product.status == UAProductStatusPurchased
            || product.status == UAProductStatusInstalled
            || product.status == UAProductStatusDownloading
            || (product.status == UAProductStatusWaiting
                && (product.isFree
                    || (product.receipt!=nil && ![product.receipt isEqualToString:@""]))))
            [installedProducts addObject:product];
    }
    if (self.status == UAInventoryStatusLoaded) {
        [self notifyObservers:@selector(inventoryGroupUpdated)];
    }
}

- (void)setOrderBy:(NSString *)key ascending:(BOOL)ascending {
    self.orderBy = key;
    orderAscending = ascending;
    if ([products count] > 0) {
        [self sortInventory];
    }
}

- (void)sortInventory {
    NSSortDescriptor *descriptor = nil;
    if (orderBy == UAContentsDisplayOrderPrice) {
        // orderBy NSNumber
        descriptor = [[NSSortDescriptor alloc] initWithKey:orderBy
                                                 ascending:orderAscending
                                                  selector:@selector(compare:)];
    } else {
        // orderBy NSString
        descriptor = [[NSSortDescriptor alloc] initWithKey:orderBy
                                                 ascending:orderAscending
                                                  selector:@selector(localizedCaseInsensitiveCompare:)];
    }

    [sortedProducts release];
    sortedProducts = [[[self productsForType:ProductTypeOrigin]
                       sortedArrayUsingDescriptors:[NSArray arrayWithObject:descriptor]]
                      retain];
    [descriptor release];
}

#pragma mark -
#pragma mark Purchase products

- (void)purchase:(NSString *)productIdentifier {

    if (status != UAInventoryStatusLoaded) {
        self.purchasingProductIdentifier = productIdentifier;
        return;
    }

    UAProduct *product = [self productWithIdentifier:productIdentifier];

    if(product.isFree == YES
       || [[UAStoreFront shared].purchaseReceipts objectForKey:product.productIdentifier] != nil) {
        [[UAStoreFront shared].downloadManager downloadIfValid:product];
    } else {
        [[UAStoreFront shared].sfObserver payForProduct:productIdentifier];
    }
}

- (void)updateAll {
    if (status != UAInventoryStatusLoaded)
        return;

    UALOG(@"Updating %d products", [updatedProducts count]);
    for(UAProduct *product in [self productsForType:ProductTypeUpdated]) {
        [self purchase:product.productIdentifier];
    }
}

#pragma mark -
#pragma mark Reachability delegate methods

- (void)hostReachStatusChanged:(NSNotification *)notification {
    UALOG(@"Network reachability changed");
    [self resetReloadCount];
    [self reloadInventory];
}

#pragma mark -
#pragma mark Util methods

- (void)setStatus:(UAInventoryStatus)aStatus {
    if (aStatus != status) {
        status = aStatus;
        [self notifyObservers:@selector(inventoryStatusChanged:)
                   withObject:[NSNumber numberWithInt:status]];
    }
}

+ (NSString*)localizedPrice:(SKProduct*)product {
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];
    NSString *formattedString = [numberFormatter stringFromNumber:product.price];
    [numberFormatter release];
    return formattedString;
}

@end
