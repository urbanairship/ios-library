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

#import "UAStoreFront.h"

#import "UA_ASIDownloadCache.h"

#import "UAStoreKitObserver.h"
#import "UAProduct.h"
#import "UAInventory.h"
#import "UAStoreFrontDownloadManager.h"


UA_VERSION_IMPLEMENTATION(StoreFrontVersion, UA_VERSION)

@implementation UAStoreFront

@synthesize sfObserver;
@synthesize inventory;
@synthesize downloadManager;
@synthesize delegate;
@synthesize purchaseReceipts;

SINGLETON_IMPLEMENTATION(UAStoreFront)

+ (BOOL)initialized {
    return g_sharedUAStoreFront ? YES : NO;
}

#pragma mark -
#pragma mark History Receipts

- (void)loadReceipts {
    self.purchaseReceipts = [NSMutableDictionary dictionaryWithContentsOfFile: kReceiptHistoryFile];
    if(purchaseReceipts == nil) {
        self.purchaseReceipts = [NSMutableDictionary dictionary];
    }
}

- (void)saveReceipts {
    // Don't want to potentially stomp on the file by saving a blank dictionary
    // when the receipts haven't finished loading
    if([purchaseReceipts count] > 0) {
        UALOG(@"Saving %d receipts", [purchaseReceipts count]);
        BOOL saved = [purchaseReceipts writeToFile:kReceiptHistoryFile atomically:YES];
        if(!saved) {
            UALOG(@"Unable to save receipt data to file");
        }
    }
}

- (void)addReceipt:(UAProduct *)product {
    UALOG(@"Add receipt for product %@", product.productIdentifier);
    NSNumber* rev = [NSNumber numberWithInt:product.revision];
    NSDictionary* data = [NSDictionary dictionaryWithObjectsAndKeys:
                          rev, @"revision",
                          product.receipt, @"receipt",
                          nil];

    [purchaseReceipts setObject:data forKey:product.productIdentifier];
    [self saveReceipts];
}

- (BOOL)hasReceipt:(UAProduct *)product {
    return [[purchaseReceipts allKeys] containsObject:product.productIdentifier];
}

#pragma mark -
#pragma mark Custom UI

static Class _uiClass;

- (Class)uiClass {
    if (!_uiClass) {
        _uiClass = NSClassFromString(STOREFRONT_UI_CLASS);
    }

    if (_uiClass == nil) {
        UALOG(@"StoreFront UI class not found.");
    }
    
    return _uiClass;
}

// This will migrate files from the oldPath to the new path
- (BOOL)directoryExistsAtPath:(NSString *)path orOldPath:(NSString *)oldPath {

    // Check for the new path - this will be false on the first run with 2.1.5, or ever
    BOOL uaExists = [[NSFileManager defaultManager] fileExistsAtPath:path];

    if (!uaExists) {
        uaExists = [[NSFileManager defaultManager] fileExistsAtPath:oldPath];

        // If the oldPath exists, then we need to move everything from that to the new path
        if(uaExists) {
            [[NSFileManager defaultManager] moveItemAtPath:oldPath
                                                    toPath:path
                                                     error:nil];
            UALOG(@"Files migrated to NSLibraryDirectory: %@",
                  [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil]);
        }
    }

    return uaExists;
}

#pragma mark -
#pragma mark Open APIs, set custom ui

+ (void)useCustomUI:(Class)customUIClass {
    _uiClass = customUIClass;
}

+ (BOOL)setDownloadDirectory:(NSString *)path {
    [UAStoreFront shared].downloadManager.createProductIDSubdir = YES;
    BOOL ret = [self setDownloadDirectory:path withProductIDSubdir:YES];
    
    return ret;
}

+ (BOOL)setDownloadDirectory:(NSString *)path withProductIDSubdir:(BOOL)makeSubdir {

    BOOL success = YES;

    // It'll be used default dir when path is nil.
    if (path == nil) {
        // The default is created in sfObserver's init
        UALOG(@"Using Default Download Directory: %@", [UAStoreFront shared].downloadManager.downloadDirectory);
        return success;
    }

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        success = [[NSFileManager defaultManager] createDirectoryAtPath:path
                                              withIntermediateDirectories:YES
                                                               attributes:nil
                                                                    error:nil];
    }

    if (success) {
        [UAStoreFront shared].downloadManager.downloadDirectory = path;
        [UAStoreFront shared].downloadManager.createProductIDSubdir = makeSubdir;
        
        UALOG(@"New Download Directory: %@", [UAStoreFront shared].downloadManager.downloadDirectory);
    }

    return success;
}

#pragma mark -
#pragma mark Open API, enter/quit StoreFront

+ (void)land {
    if (g_sharedUAStoreFront) {
        [[SKPaymentQueue defaultQueue] removeTransactionObserver:[UAStoreFront shared].sfObserver];
        RELEASE_SAFELY(g_sharedUAStoreFront);
    }
}

+ (void)displayStoreFront:(UIViewController *)viewController animated:(BOOL)animated {
    [[[UAStoreFront shared] uiClass] displayStoreFront:viewController animated:animated];
}

+ (void)displayStoreFront:(UIViewController *)viewController withProductID:(NSString *)ID animated:(BOOL)animated {
    [[[UAStoreFront shared] uiClass] displayStoreFront:viewController withProductID:ID animated:animated];
}

+ (void)quitStoreFront {
    
    // call the optional storeFrontWillHide delegate method
    NSObject<UAStoreFrontDelegate> *sfDelegate = [UAStoreFront shared].delegate;    
    if ([sfDelegate respondsToSelector:@selector(storeFrontWillHide)]) {
        [sfDelegate performSelectorOnMainThread:@selector(storeFrontWillHide) 
                                     withObject:nil 
                                  waitUntilDone:YES];
    }
    
    [[[UAStoreFront shared] uiClass] quitStoreFront];
    
}

#pragma mark -
#pragma mark Open API, set inventory products order

+ (void)setOrderBy:(NSString *)key {
    [self setOrderBy:key ascending:NO];
}

+ (void)setOrderBy:(NSString *)key ascending:(BOOL)ascending {
    [[UAStoreFront shared].inventory setOrderBy:key ascending:ascending];
}

#pragma mark -
#pragma mark Open API, directly purchase a product

+ (void)purchase:(NSString *)productIdentifier {
    [[UAStoreFront shared].inventory purchase:productIdentifier];
}

#pragma mark -
#pragma mark Open API, registration of inventory/skpayment observers

+ (void)registerObserver:(id)observer {
    [[UAStoreFront shared].inventory addObserver:observer];
    [[UAStoreFront shared].sfObserver addObserver:observer];
}

+ (void)unregisterObserver:(id)observer {
    [[UAStoreFront shared].inventory removeObserver:observer];
    [[UAStoreFront shared].sfObserver removeObserver:observer];
}

#pragma mark -
#pragma mark Open API, load/reload inventory

+ (void)loadInventory {
    [[UAStoreFront shared].inventory loadInventory];
}

+ (void)resetAndLoadInventory {
    [[UAStoreFront shared].inventory resetReloadCount];
    [[UAStoreFront shared].inventory reloadInventory];
}

+ (void)reloadInventoryIfFailed {
    if ([UAStoreFront shared].inventory.status == UAInventoryStatusFailed) {
        // if inventory status is failed, then this block only gets invoked when
        // SF displayed again
        [UAStoreFront resetAndLoadInventory];
    }
}

#pragma mark -
#pragma mark Open API, products operations

+ (NSArray *)productsForType:(UAProductType)type {
    return [[UAStoreFront shared].inventory productsForType:type];
}

+ (void)updateAllProducts {
    [[UAStoreFront shared].inventory updateAll];
}

+ (void)restoreAllProducts {
    [[UAStoreFront shared].sfObserver restoreAll];
}

#pragma mark -
#pragma mark Memory management

-(void)dealloc {
    [inventory removeObserver:sfObserver];
    [inventory removeObserver:downloadManager];

    RELEASE_SAFELY(sfObserver);
    RELEASE_SAFELY(inventory);
    RELEASE_SAFELY(downloadManager);
    self.delegate = nil;

    RELEASE_SAFELY(purchaseReceipts);

    [super dealloc];
}

- (void)initProperties {
    downloadManager = [[UAStoreFrontDownloadManager alloc] init];
    sfObserver = [[UAStoreKitObserver alloc] init];
    inventory = [[UAInventory alloc] init];
    
    [inventory addObserver:downloadManager];
    [inventory addObserver:sfObserver];
}

-(id)init {
    UALOG(@"Initialize StoreFront.");

    if (self = [super init]) {
        // In StoreFront, we set the cache policy to use cache if possible.
        // And currently we only use this download cache in UAAsyncImageView.
        [[UA_ASIDownloadCache sharedCache] setDefaultCachePolicy:UA_ASIAskServerIfModifiedWhenStaleCachePolicy|UA_ASIFallbackToCacheIfLoadFailsCachePolicy];

        [self loadReceipts];

        [self initProperties];
    }
    return self;
}

@end
