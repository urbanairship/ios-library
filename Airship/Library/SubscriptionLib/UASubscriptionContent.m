/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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
@synthesize iconURL;
@synthesize previewURL;
@synthesize downloadURL;
@synthesize revision;
@synthesize fileSize;
@synthesize description;
@synthesize progress;
@synthesize downloaded;
@dynamic downloading;

- (void)dealloc {
    RELEASE_SAFELY(contentName);
    RELEASE_SAFELY(iconURL);
    RELEASE_SAFELY(previewURL);
    RELEASE_SAFELY(downloadURL);
    RELEASE_SAFELY(description);
    [super dealloc];
}

- (id)initWithDict:(NSDictionary *)dict {
    if (!(self = [super init]))
        return nil;

    self.contentName = [dict objectForKey:@"name"];
    self.subscriptionKey = [dict objectForKey:@"subscription_key"];
    self.iconURL = [NSURL URLWithString:[dict objectForKey:@"icon_url"]];
    self.previewURL = [NSURL URLWithString:[dict objectForKey:@"preview_url"]];
    self.downloadURL = [NSURL URLWithString:[dict objectForKey:@"download_url"]];
    self.description = [dict objectForKey:@"description"];
    self.revision = [[dict objectForKey:@"current_revision"] intValue];
    self.fileSize = [[dict objectForKey:@"file_size"] intValue];
    self.downloaded = [[NSUserDefaults standardUserDefaults] boolForKey:[downloadURL description]];
    progress = 0;
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