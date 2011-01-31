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

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "UAAsycImageView.h"
#import "UAObservable.h"
#import "UA_ASIProgressDelegate.h"

typedef enum UAProductStatus {
    UAProductStatusUnpurchased = 0,
    UAProductStatusWaiting,          // transient state
    UAProductStatusPurchased,
    UAProductStatusDownloading,      // transient state
    //UAProductStatusDecompressing,  // transient state
    UAProductStatusInstalled,
    UAProductStatusHasUpdate
} UAProductStatus;


@interface UAProduct : UAObservable <NSCopying, UA_ASIProgressDelegate> {
    NSString *productIdentifier;
    NSURL *previewURL;
    UAAsyncImageView *preview;
    NSURL *iconURL;
    UAAsyncImageView *icon;
    NSURL *downloadURL;
    int revision;
    double fileSize;
    NSString* price;
    NSDecimalNumber* priceNumber;
    NSString* productDescription;
    NSString* title;
    NSString* receipt;
    BOOL isFree;

    UAProductStatus status;

    // for downloading status
    float progress;
    SKPaymentTransaction *transaction;
}

@property (nonatomic, retain) NSString *productIdentifier;
@property (nonatomic, retain) NSURL *previewURL;
@property (nonatomic, retain) UAAsyncImageView *preview;
@property (nonatomic, retain) NSURL *iconURL;
@property (nonatomic, retain) UAAsyncImageView *icon;
@property (nonatomic, retain) NSURL *downloadURL;
@property (nonatomic, assign) int revision;
@property (nonatomic, assign) double fileSize;
@property (nonatomic, retain) NSString* price;
@property (nonatomic, retain) NSDecimalNumber* priceNumber;
@property (nonatomic, retain) NSString* productDescription;
@property (nonatomic, retain) NSString* title;
@property (nonatomic, copy) NSString* receipt;
@property (nonatomic, assign) BOOL isFree;
@property (nonatomic, assign) UAProductStatus status;
@property (nonatomic, assign) float progress;

@property (nonatomic, assign) SKPaymentTransaction *transaction;

- (id)init;
+ (UAProduct *)productFromDictionary:(NSDictionary *)item;
- (NSComparisonResult)compare:(UAProduct*)product;
- (void)resetStatus;
- (BOOL)hasUpdate;

- (void)setProgress:(float)_progress;

@end


