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

@interface UASubscriptionProduct : NSObject {
    NSString *productIdentifier;
    NSString *subscriptionKey;
    NSString *subscriptionName;
    NSURL *subscribeURL;
    NSURL *previewURL;
    NSURL *iconURL;
    int duration;

    //property from SKProduct
    NSString *title;
    NSString *productDescription;
    NSString *price;
    NSDecimalNumber *priceNumber;

    // For purchased product
    BOOL purchased;
    NSDate *startDate;
    NSDate *endDate;
    
    // For UI
    BOOL isPurchasing;
}

@property (nonatomic, retain) NSString *productIdentifier;
@property (nonatomic, retain) NSURL *subscribeURL;
@property (nonatomic, retain) NSURL *previewURL;
@property (nonatomic, retain) NSURL *iconURL;
@property (nonatomic, assign) int duration;
@property (nonatomic, retain) NSString *subscriptionKey;
@property (nonatomic, retain) NSString *subscriptionName;

@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *productDescription;
@property (nonatomic, retain) NSString *price;
@property (nonatomic, retain) NSDecimalNumber *priceNumber;

@property (nonatomic, assign) BOOL purchased;
@property (nonatomic, retain) NSDate *startDate;
@property (nonatomic, retain) NSDate *endDate;

@property (nonatomic, assign) BOOL isPurchasing;

- (id)initWithDict:(NSDictionary *)dict;
- (id)initWithSubscriptionProduct:(UASubscriptionProduct *)sp;
- (void)setPurchasingInfo:(NSDictionary *)purchasingInfo;

@end
