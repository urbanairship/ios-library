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

#import "UASubscriptionContent.h"
#import "UAGlobal.h"

@implementation UASubscriptionContent

@synthesize contentName;
@synthesize subscriptionKey;
@synthesize contentKey;
@synthesize productIdentifier;
@synthesize iconURL;
@synthesize previewURL;
@synthesize downloadURL;
@synthesize revision;
@synthesize fileSize;
@synthesize description;
@synthesize publishDate;
@synthesize progress;
@synthesize downloaded;
@dynamic downloading;

- (void)dealloc {

    self.contentName = nil;
    self.contentKey = nil;
    self.subscriptionKey = nil;
    self.productIdentifier = nil;
    self.iconURL = nil;
    self.previewURL = nil;
    self.downloadURL = nil;
    
    self.description = nil;
    self.publishDate = nil;
    
    [super dealloc];
    
}

- (id)initWithDict:(NSDictionary *)dict {
    if (!(self = [super init]))
        return nil;

    self.contentName = [dict objectForKey:@"name"];
    self.contentKey = [dict objectForKey:@"content_key"];
    self.subscriptionKey = [dict objectForKey:@"subscription_key"];
	self.productIdentifier = [dict objectForKey:@"product_id"];
    self.iconURL = [NSURL URLWithString:[dict objectForKey:@"icon_url"]];
    self.previewURL = [NSURL URLWithString:[dict objectForKey:@"preview_url"]];
    self.downloadURL = [NSURL URLWithString:[dict objectForKey:@"download_url"]];
    self.description = [dict objectForKey:@"description"];
    self.revision = [[dict objectForKey:@"current_revision"] intValue];
    self.fileSize = [[dict objectForKey:@"file_size"] intValue];
    self.downloaded = [[NSUserDefaults standardUserDefaults] boolForKey:[downloadURL description]];
    progress = 0;
    
    // Parse and set the publish date
    NSDateFormatter *generateDateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
    
	[generateDateFormatter setLocale:enUSPOSIXLocale];
	[generateDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"]; //2010-07-20 15:48:46
	[generateDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	
    // refs http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns
    // Date Format Patterns 'ZZZ' is for date strings like '-0800' and 'ZZZZ'
    // is used for 'GMT-08:00', so i just set the timezone string as '+0000' which
    // is equal to 'UTC'
    NSString *publishDateStr = [NSString stringWithFormat: @"%@%@", [dict objectForKey:@"publish_date"], @" +0000"];
    self.publishDate = [generateDateFormatter dateFromString:publishDateStr];
    
    return self;
}

- (BOOL)isEqual:(id)anObject {
    if (anObject == nil || ![anObject isKindOfClass:[self class]])
        return NO;

    UASubscriptionContent *other = (UASubscriptionContent *)anObject;
    return [self.subscriptionKey isEqual:other.subscriptionKey]
           && [self.contentName isEqual:other.contentName];
}

- (NSComparisonResult)compare:(UASubscriptionContent *)other {
    if (other == nil)
        return NSOrderedDescending;

    NSComparisonResult res = [self.subscriptionKey caseInsensitiveCompare:other.subscriptionKey];
    if (res == NSOrderedSame)
        res = [self.contentName caseInsensitiveCompare:other.contentName];

    return res;
}

- (void)setProgress:(float)p {
    progress = p;
    [self notifyObservers:@selector(setProgress:) withObject:[NSNumber numberWithFloat:p]];
    if (p >= 1) {
        downloaded = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:[downloadURL description]];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (BOOL)downloading {
    if (progress <= 0 || progress >= 1)
        return NO;
    else
        return YES;
}

@end