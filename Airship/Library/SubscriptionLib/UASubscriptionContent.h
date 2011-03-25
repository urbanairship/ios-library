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
#import "UAObservable.h"
#import "UA_ASIProgressDelegate.h"

@interface UASubscriptionContent : UAObservable <UA_ASIProgressDelegate> {
    NSString *contentName;
    NSString *subscriptionKey;
	NSString *productIdentifier;
    NSURL *iconURL;
    NSURL *previewURL;
    NSURL *downloadURL;
    int revision;
    int fileSize;
    NSString *description;

    BOOL downloaded;
    float progress;
}

@property (nonatomic, retain) NSString *contentName;
@property (nonatomic, retain) NSString *subscriptionKey;
@property (nonatomic, retain) NSString *productIdentifier;
@property (nonatomic, retain) NSURL *iconURL;
@property (nonatomic, retain) NSURL *previewURL;
@property (nonatomic, retain) NSURL *downloadURL;
@property (nonatomic, assign) int revision;
@property (nonatomic, assign) int fileSize;
@property (nonatomic, retain) NSString *description;
@property (nonatomic, assign) float progress;
@property (nonatomic, assign) BOOL downloaded;
@property (nonatomic, readonly, assign) BOOL downloading;

- (id)initWithDict:(NSDictionary *)dict;

@end
