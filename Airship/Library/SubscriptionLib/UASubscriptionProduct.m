/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

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

#import "UASubscriptionProduct.h"
#import "UAGlobal.h"
#import <StoreKit/StoreKit.h>

@implementation UASubscriptionProduct

@synthesize productIdentifier;
@synthesize subscribeURL;
@synthesize previewURL;
@synthesize iconURL;
@synthesize duration;
@synthesize subscriptionKey;
@synthesize subscriptionName;
@synthesize skProduct;
@synthesize title;
@synthesize productDescription;
@synthesize price;
@synthesize priceNumber;
@synthesize purchased;
@synthesize startDate;
@synthesize endDate;
@synthesize isPurchasing;
@synthesize isForSale;
@synthesize productType;
@synthesize autorenewableDuration;

- (void)dealloc {
    RELEASE_SAFELY(skProduct);
    RELEASE_SAFELY(productIdentifier);
    RELEASE_SAFELY(subscribeURL);
    RELEASE_SAFELY(previewURL);
    RELEASE_SAFELY(iconURL);
    RELEASE_SAFELY(subscriptionKey);
    RELEASE_SAFELY(subscriptionName);
    RELEASE_SAFELY(title);
    RELEASE_SAFELY(productDescription);
    RELEASE_SAFELY(price);
    RELEASE_SAFELY(priceNumber);
    RELEASE_SAFELY(startDate);
    RELEASE_SAFELY(endDate);

    [super dealloc];
}

- (id)initWithDict:(NSDictionary *)dict {
    if (!(self = [super init])) {
        return nil;
    }
    
    UALOG(@"Product dict: %@",[dict description]);
    
    self.productIdentifier = [dict objectForKey:@"product_id"];
    self.subscriptionKey = [dict objectForKey:@"subscription_key"];
    self.subscriptionName = [dict objectForKey:@"name"];
    self.subscribeURL = [NSURL URLWithString:[dict objectForKey:@"subscribe_url"]];
    self.previewURL = [NSURL URLWithString:[dict objectForKey:@"preview_url"]];
    self.iconURL = [NSURL URLWithString:[dict objectForKey:@"icon_url"]];

    //set the duration if available (not sent for autorenewables)
    id durationValue = [dict objectForKey:@"duration_in_days"];
    if (durationValue && (NSNull *)durationValue != [NSNull null]) { 
        self.duration = [(NSNumber *)durationValue intValue];
    }
    
    self.autorenewableDuration = UAAutorenewableDurationNone; // init to none
    id arDuration = [dict objectForKey:@"ar_duration"];
    if (arDuration && (NSNull *)arDuration != [NSNull null]) { 
        NSString *arDurationString = (NSString *)arDuration;
        if ([@"7 Days" isEqualToString:arDurationString]) {
            self.autorenewableDuration = UAAutorenewableDuration7Days;
            self.duration = 7;
        } else if ([@"1 Month" isEqualToString:arDurationString]) {
            self.autorenewableDuration = UAAutorenewableDuration1Month;
            self.duration = 30;
        } else if ([@"2 Months" isEqualToString:arDurationString]) {
            self.autorenewableDuration = UAAutorenewableDuration2Months;
            self.duration = 61;
        } else if ([@"3 Months" isEqualToString:arDurationString]) {
            self.autorenewableDuration = UAAutorenewableDuration3Months;
            self.duration = 92;
        } else if ([@"6 Months" isEqualToString:arDurationString]) {
            self.autorenewableDuration = UAAutorenewableDuration6Months;
            self.duration = 183;
        } else if ([@"1 Year" isEqualToString:arDurationString]) {
            self.autorenewableDuration = UAAutorenewableDuration1Year;
            self.duration = 365;
        }
        UALOG(@"Duration value = %d", self.autorenewableDuration);
    }
    
    // the integer enumeration values were chosen to agree with this field's range of values
    self.productType = [[dict objectForKey:@"product_type"] intValue];

    for (SKPaymentTransaction *transaction in [[SKPaymentQueue defaultQueue] transactions]) {
        if ([transaction.payment.productIdentifier isEqualToString:self.productIdentifier]) {
            self.isPurchasing = YES;
        }
    }

    return self;
}

- (id)initWithSubscriptionProduct:(UASubscriptionProduct *)sp {

    if (!(self = [super init]))
        return nil;
	
	self.productIdentifier = sp.productIdentifier;
	self.subscriptionKey = sp.subscriptionKey;
	self.subscriptionName = sp.subscriptionName;
	self.subscribeURL = sp.subscribeURL;
	self.previewURL = sp.previewURL;
	self.iconURL = sp.iconURL;
	self.duration = sp.duration;
    self.skProduct = sp.skProduct;
	self.title = sp.title;
	self.productDescription = sp.productDescription;
	self.price = sp.price;
	self.priceNumber = sp.priceNumber;
	self.purchased = sp.purchased;
	self.startDate = sp.startDate;
	self.endDate = sp.endDate;
	self.isPurchasing = sp.isPurchasing;
    self.isForSale = sp.isForSale;
    self.productType = sp.productType;
    self.autorenewableDuration = sp.autorenewableDuration;
	
	return self;
}

- (BOOL)isEqual:(id)object {
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    UASubscriptionProduct *other = (UASubscriptionProduct *)object;
    return [self.productIdentifier isEqualToString:other.productIdentifier]
           && self.duration == other.duration
           && self.autorenewableDuration == other.autorenewableDuration
           && [self.title isEqualToString:other.title];
}

- (NSComparisonResult)compareByDuration:(UASubscriptionProduct *)otherProduct {
    
    int d = self.duration - otherProduct.duration;
    if (d < 0)
        return NSOrderedAscending;
    else if (d == 0)
        return NSOrderedSame;
    else
        return NSOrderedDescending;
}

- (NSComparisonResult)compareByDate:(UASubscriptionProduct *)otherProduct {
    return [self.startDate compare:otherProduct.startDate];
}

- (void)setPurchasingInfo:(NSDictionary *)purchasingInfo {
	
    NSDateFormatter *generateDateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];

	[generateDateFormatter setLocale:enUSPOSIXLocale];
	[generateDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"]; //2010-07-20 15:48:46
	[generateDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	
    // refs http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns
    // Date Format Patterns 'ZZZ' is for date strings like '-0800' and 'ZZZZ'
    // is used for 'GMT-08:00', so i just set the timezone string as '+0000' which
    // is equal to 'UTC'
    NSString *endstr = [NSString stringWithFormat: @"%@%@", [purchasingInfo objectForKey:@"end"], @" +0000"];
    NSString *startstr = [NSString stringWithFormat: @"%@%@", [purchasingInfo objectForKey:@"start"], @" +0000"];

    self.startDate = [generateDateFormatter dateFromString: startstr];
    self.endDate= [generateDateFormatter dateFromString: endstr];

    purchased = YES;
}

@end
