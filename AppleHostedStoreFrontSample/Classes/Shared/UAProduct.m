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

#import "UAProduct.h"
#import "UAirship.h"
#import "UAStoreFront.h"
#import "UAStoreFrontDownloadManager.h"

@implementation UAProduct

@synthesize productIdentifier;
@synthesize previewURL;
@synthesize preview;
@synthesize iconURL;
@synthesize icon;
@synthesize downloadURL;
@synthesize revision;
@synthesize price;
@synthesize priceNumber;
@synthesize productDescription;
@synthesize skProduct;
@synthesize title;
@synthesize receipt;
@synthesize isFree;
@synthesize fileSize;
@synthesize status;
@synthesize progress;
@synthesize transaction;

#pragma mark -

- (void)dealloc {
    RELEASE_SAFELY(skProduct);
    RELEASE_SAFELY(productIdentifier);
    RELEASE_SAFELY(previewURL);
    RELEASE_SAFELY(preview);
    RELEASE_SAFELY(iconURL);
    RELEASE_SAFELY(icon);
    RELEASE_SAFELY(downloadURL);
    RELEASE_SAFELY(price);
    RELEASE_SAFELY(priceNumber);
    RELEASE_SAFELY(productDescription);
    RELEASE_SAFELY(title);
    RELEASE_SAFELY(receipt);
    transaction = nil;
    [super dealloc];
}

- (id)init {
    if (!(self = [super init]))
        return nil;

    self.priceNumber = [NSDecimalNumber zero];
    self.receipt = @"";
    self.status = UAProductStatusUnpurchased;
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    UAProduct *copy = [[[self class] allocWithZone:zone] init];
    copy.skProduct = self.skProduct;
    copy.productIdentifier = self.productIdentifier;
    copy.previewURL = self.previewURL;
    copy.preview = self.preview;
    copy.iconURL = self.iconURL;
    copy.icon = self.icon;
    copy.downloadURL = self.downloadURL;
    copy.revision = self.revision;
    copy.fileSize = self.fileSize;
    copy.price = self.price;
    copy.priceNumber = self.priceNumber;
    copy.productDescription = self.productDescription;
    copy.title = self.title;
    copy.receipt = self.receipt;
    copy.isFree = self.isFree;
    copy.status = self.status;

    return copy;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[product id:%@, status:%d]", productIdentifier, status];
}

- (NSComparisonResult)compare:(UAProduct *)product {
    return [self.title compare:product.title];
}

- (BOOL)isEqual:(id)anObject {
    if (![anObject isKindOfClass:[UAProduct class]] || !anObject)
        return NO;

    UAProduct *other = (UAProduct *)anObject;
    return ([self.productIdentifier isEqualToString:other.productIdentifier]
            && self.status == other.status
            && [self.downloadURL isEqual:other.downloadURL]
            && [self.title isEqualToString:other.title]);
}

- (NSString *)receipt {
    return [[receipt copy] autorelease];
}

+ (UAProduct *)productFromDictionary:(NSDictionary *)item {

    UAProduct* product = [[UAProduct alloc] init];
    product.productIdentifier = [item objectForKey: @"product_id"];

    NSString* previewURL =  [item objectForKey: @"preview_url"]==nil ? @"" : [item objectForKey: @"preview_url"];
    if (previewURL != nil && ![previewURL isEqualToString:@""]) {
        product.previewURL = [NSURL URLWithString: previewURL];
    }

    NSString* downloadURL = [item objectForKey: @"download_url"]==nil ? @"" : [item objectForKey: @"download_url"];
    product.downloadURL = [NSURL URLWithString: downloadURL];

    NSString* iconURL = [item objectForKey: @"icon_url"]== nil ? @"" : [item objectForKey: @"icon_url"];
    product.iconURL = [NSURL URLWithString: iconURL];

    product.title = [item objectForKey: @"name"];
    product.isFree = NO;
    if([item objectForKey: @"free"] != [NSNull null] && [[item objectForKey: @"free"] intValue] != 0) {
        product.isFree = YES;
        product.productDescription = [item objectForKey: @"description"];
        product.price = @"FREE";
    }

    product.revision = [[item objectForKey: @"current_revision"] intValue];
    product.fileSize = [[item objectForKey:@"file_size"] doubleValue];

    [product resetStatus];

    return [product autorelease];
}

#pragma mark -
#pragma mark Status Methods

- (void)notifyInventoryObservers:(UAProductStatus)aStatus {
    [[UAStoreFront shared].inventory notifyObservers:@selector(inventoryProductsChanged:)
                                          withObject:[NSNumber numberWithInt:status]];
}

- (void)setStatus:(UAProductStatus)aStatus {
    if (aStatus != status) {
        status = aStatus;
        [self notifyObservers:@selector(productStatusChanged:)
                   withObject:[NSNumber numberWithInt:status]];
        [self notifyInventoryObservers:aStatus];
    }
}

- (void)resetStatus {
    // Check permament status
    NSDictionary *item = [[UAStoreFront shared].purchaseReceipts objectForKey:productIdentifier];
    if (item != nil) {
        receipt = [[item objectForKey:@"receipt"] copy];
        if(revision > [[item objectForKey:@"revision"] intValue]) {
            self.status = UAProductStatusHasUpdate;
        } else {
            if ([[UAStoreFront shared].downloadManager hasPendingProduct:self]) {
                self.status = UAProductStatusPurchased;
            } else if ([[UAStoreFront shared].downloadManager hasDecompressingProduct:self]) {
                self.status = UAProductStatusDecompressing;
            } else {
                self.status = UAProductStatusInstalled;
            }
        }
    } else {
        self.status = UAProductStatusUnpurchased;
        receipt = @"";
    }
}

- (void)setProgress:(float)_progress {
    if (progress != _progress) {
        progress = _progress;
        [self notifyObservers:@selector(productProgressChanged:)
                   withObject:[NSNumber numberWithFloat:progress]];
    }
}

- (BOOL)hasUpdate {
    NSDictionary* item = [[UAStoreFront shared].purchaseReceipts objectForKey:productIdentifier];
    if (item != nil && revision > [[item objectForKey:@"revision"] intValue])
        return YES;
    else
        return NO;
}

@end
