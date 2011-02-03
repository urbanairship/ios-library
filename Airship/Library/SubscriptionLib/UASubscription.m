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

#import "UASubscription.h"
#import "UAGlobal.h"
#import "UASubscriptionProduct.h"

@implementation UASubscription

@synthesize key;
@synthesize name;
@synthesize subscribed;
@synthesize products;
@synthesize purchasedProducts;
@synthesize availableContents;
@synthesize downloadedContents;
@synthesize undownloadedContents;

- (void)dealloc {
    RELEASE_SAFELY(key);
    RELEASE_SAFELY(name);
    RELEASE_SAFELY(products);
    RELEASE_SAFELY(purchasedProducts);
    RELEASE_SAFELY(availableContents);
    RELEASE_SAFELY(downloadedContents);
    RELEASE_SAFELY(undownloadedContents);

    [super dealloc];
}

- (id)initWithKey:(NSString *)aKey name:(NSString *)aName {
    if (!(self = [super init]))
        return nil;

    key = [aKey copy];
    name = [aName copy];
    products = [[NSMutableArray alloc] init];
    purchasedProducts = [[NSMutableArray alloc] init];
    availableContents = [[NSMutableArray alloc] init];
    downloadedContents = [[NSMutableArray alloc] init];
    undownloadedContents = [[NSMutableArray alloc] init];

    return self;
}

- (BOOL)isEqual:(id)object {
    if (!object || ![object isKindOfClass:[self class]])
        return NO;

    if (self == object)
        return YES;

    UASubscription *other = (UASubscription *)object;
    return [self.key isEqualToString:other.key];
}

- (NSUInteger)hash {
    return [key hash];
}

- (NSComparisonResult)compare:(UASubscription *)otherSubscription {
    return [self.name caseInsensitiveCompare:otherSubscription.name];
}

#pragma mark -

- (void)setProductsWithArray:(NSArray *)productArray {
    [products setArray:productArray];
    [products sortUsingSelector:@selector(compareByDuration:)];
}

- (void)setContentsWithArray:(NSArray *)contents {
    if (!contents)
        return;

    [availableContents setArray:contents];
    [availableContents sortUsingSelector:@selector(compare:)];

    [self filterDownloadedContents];
}

- (void)setPurchasedProduct:(NSDictionary *)purchasingInfo {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"productIdentifier like[c] %@",
                              [purchasingInfo objectForKey:@"product_id"]];
    UASubscriptionProduct *product = [[products filteredArrayUsingPredicate:predicate] objectAtIndex:0];
    
	if (product) {
        UASubscriptionProduct *purchasedProduct = [[UASubscriptionProduct alloc] initWithSubscriptionProduct:product];
        [purchasedProduct setPurchasingInfo:purchasingInfo];
        [purchasedProducts addObject:purchasedProduct];
        [purchasedProduct release];
    }
}

- (void)setPurchasedProductsWithArray:(NSArray *)infos {
    [purchasedProducts removeAllObjects];

    for (NSDictionary *info in infos) {
        subscribed = YES;
        [self setPurchasedProduct:info];
    }

    [purchasedProducts sortUsingSelector:@selector(compareByDate:)];
}

- (void)filterDownloadedContents {
    [downloadedContents removeAllObjects];
    [undownloadedContents removeAllObjects];

    if ([availableContents count]) {

        [downloadedContents setArray:
         [availableContents filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:@"downloaded == YES"]]];

        [undownloadedContents setArray:
         [availableContents filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:@"downloaded == NO"]]];
    }

    [downloadedContents sortedArrayUsingSelector:@selector(compare:)];
    [undownloadedContents sortedArrayUsingSelector:@selector(compare:)];
}

@end
