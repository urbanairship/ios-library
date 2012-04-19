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

#import "UASubscriptionDownloadManager.h"
#import "UASubscriptionContent.h"
#import "UA_SBJsonParser.h"
#import "UAGlobal.h"
#import "UAUser.h"
#import "UAirship.h"
#import "UAUtils.h"
#import "UASubscription.h"
#import "UAContentInventory.h"
#import "UASubscriptionManager.h"
#import "UASubscriptionInventory.h"
#import "UAContentURLCache.h"
#import "UADownloadContent.h"

//private methods
@interface UASubscriptionDownloadManager()

- (void)addPendingSubscriptionContent:(UASubscriptionContent *)subscriptionContent;
- (void)removePendingSubscriptionContent:(UASubscriptionContent *)subscriptionContent;
- (void)addDecompressingSubscriptionContent:(UASubscriptionContent *)subscriptionContent;
- (void)removeDecompressingSubscriptionContent:(UASubscriptionContent *)subscriptionContent;

- (void)downloadDidFail:(UADownloadContent *)downloadContent;

- (UAZipDownloadContent *)zipDownloadContentForSubscriptionContent:(UASubscriptionContent *)subscriptionContent;
@end

@implementation UASubscriptionDownloadManager

@synthesize downloadDirectory;
@synthesize contentURLCache;
@synthesize createProductIDSubdir;
@synthesize pendingSubscriptionContent;
@synthesize decompressingSubscriptionContent;
@synthesize currentlyDecompressingContent;

- (id)init {
    if (!(self = [super init]))
        return nil;
    
    [[UASubscriptionManager shared] addObserver:self];
    
    downloadManager = [[UADownloadManager alloc] init];
    downloadManager.delegate = self;
    self.downloadDirectory = kUADownloadDirectory;
    self.createProductIDSubdir = YES;
    
    self.contentURLCache = [UAContentURLCache cacheWithExpirationInterval:kDefaultUrlCacheExpirationInterval //24 hours
                                                                 withPath:kSubscriptionURLCacheFile];
    
    [self loadPendingSubscriptionContent];
    [self loadDecompressingSubscriptionContent];
    
    self.currentlyDecompressingContent = [NSMutableArray array];
    
    return self;
}

- (void)dealloc {
    [[UASubscriptionManager shared] removeObserver:self];
    
    RELEASE_SAFELY(downloadManager);
    RELEASE_SAFELY(downloadDirectory);
    RELEASE_SAFELY(pendingSubscriptionContent);
    RELEASE_SAFELY(decompressingSubscriptionContent);
    RELEASE_SAFELY(currentlyDecompressingContent);
    RELEASE_SAFELY(contentURLCache);
    
    [super dealloc];
}

- (void)checkDownloading:(UASubscriptionContent *)content {
    for (UAZipDownloadContent *downloadContent in [downloadManager allDownloadingContents]) {
        UASubscriptionContent *oldContent = [downloadContent userInfo];
        if ([content isEqual:oldContent]) {
            content.progress = oldContent.progress;
            downloadContent.userInfo = content;
            downloadContent.progressDelegate = content;
            [downloadManager updateProgressDelegate:downloadContent];
            return;
        }
    }
}

- (void)downloadContent:(UASubscriptionContent *)content withContentURL:(NSURL *)contentURL {
    
    UAZipDownloadContent *zipDownloadContent = [self zipDownloadContentForSubscriptionContent:content];

    if (!contentURL) {
        UALOG(@"Error: no actual download_url returned from download_url");
        [self downloadDidFail:zipDownloadContent];
        return;
    }

    zipDownloadContent.downloadRequestURL = contentURL;
    zipDownloadContent.requestMethod = kRequestMethodGET;

    [downloadManager download:zipDownloadContent];
}

- (void)verifyDidSucceed:(UADownloadContent *)downloadContent {
    UASubscriptionContent *content = downloadContent.userInfo;
    id result = [UAUtils parseJSON:downloadContent.responseString];
    NSString *contentURLString = [result objectForKey:@"download_url"];
    UALOG(@"Actual download URL: %@", contentURLString);
    
    //cache the content url
    UALOG(@"caching content url: %@ for download url: %@", contentURLString, content.downloadURL);
    NSURL *contentURL = [NSURL URLWithString:contentURLString];
    [contentURLCache setContent:contentURL forProductURL:content.downloadURL withVersion:[NSNumber numberWithInt:content.revision]];
    
    [self downloadContent:content withContentURL:contentURL];
}

- (NSMutableArray *)loadSubscriptionContentFromFilePath:(NSString *)filePath {
    return [NSMutableArray arrayWithContentsOfFile:filePath];
}

- (BOOL)saveSubscriptionContent:(NSMutableArray *)contentArray toFilePath:(NSString *)filePath {
    return [contentArray writeToFile:filePath atomically:YES];
}


#pragma mark -
#pragma mark Pending Transactions Management

- (void)loadPendingSubscriptionContent {
    self.pendingSubscriptionContent = [self loadSubscriptionContentFromFilePath:kPendingSubscriptionContentFile];
    if (pendingSubscriptionContent == nil) {
        self.pendingSubscriptionContent = [NSMutableArray array];
    }
}

- (void)savePendingSubscriptionContent {
    if (![self saveSubscriptionContent:pendingSubscriptionContent toFilePath:kPendingSubscriptionContentFile]) {
        UALOG(@"Failed to save pending SubscriptionContent to file path: %@", kPendingSubscriptionContentFile);
    }
}

- (BOOL)hasPendingSubscriptionContent:(UASubscriptionContent *)subscriptionContent {
    return [pendingSubscriptionContent containsObject:subscriptionContent.contentKey];
}

- (void)addPendingSubscriptionContent:(UASubscriptionContent *)subscriptionContent {
    if (![pendingSubscriptionContent containsObject:subscriptionContent.contentKey]) {
        [pendingSubscriptionContent addObject:subscriptionContent.contentKey];
        [self savePendingSubscriptionContent];
    }
}

- (void)removePendingSubscriptionContent:(UASubscriptionContent *)subscriptionContent {
    [pendingSubscriptionContent removeObject:subscriptionContent.contentKey];
    [self savePendingSubscriptionContent];
}

- (void)resumePendingSubscriptionContent {
    UALOG(@"Resume pending SubscriptionContent in purchasing queue %@", pendingSubscriptionContent);

    //if the inventory is currently loading the contents will be empty, so there is
    //no point in continuing. log a warning so that it's clear this is the case
    if (![UASubscriptionManager shared].inventory.hasLoaded) {
        UALOG(@"Warning: inventory has not yet loaded, cancelling resume");
        return;
    }

    for (NSString *identifier in pendingSubscriptionContent) {
        UASubscriptionContent *subscriptionContent = [[UASubscriptionManager shared].inventory contentForKey:identifier];
        //if subscriptionContent is nil, the inventory is either currently invalidated or the contents have been
        //changed remotely
        if (subscriptionContent) {
            [self download:subscriptionContent];
        } else {
            UALOG(@"Warning: no subscription content found for pending download identifier %@", identifier);
        }
    }
    
    // Reconnect downloading request with newly created subscription content
    for (UAZipDownloadContent *downloadContent in [downloadManager allDownloadingContents]) {
        
        UASubscriptionContent *oldSubscriptionContent = [downloadContent userInfo];
        UASubscriptionContent *newSubscriptionContent = [[UASubscriptionManager shared].inventory contentForKey:oldSubscriptionContent.contentKey];
        
        downloadContent.userInfo = newSubscriptionContent;
        downloadContent.progressDelegate = newSubscriptionContent;
        [downloadManager updateProgressDelegate:downloadContent];
    }
}

#pragma mark -
#pragma mark Decompressing SubscriptionContent Management

- (UAZipDownloadContent *)zipDownloadContentForSubscriptionContent:(UASubscriptionContent *)subscriptionContent {
    UAZipDownloadContent *zipDownloadContent = [[[UAZipDownloadContent alloc] init] autorelease];
    zipDownloadContent.userInfo = subscriptionContent;
    zipDownloadContent.downloadFileName = subscriptionContent.contentKey;
    zipDownloadContent.downloadPath = [downloadDirectory stringByAppendingPathComponent:
                                       [NSString stringWithFormat: @"%@.zip", subscriptionContent.subscriptionKey]];
    zipDownloadContent.progressDelegate = subscriptionContent;
    
    return zipDownloadContent;
}

- (void)decompressZipDownloadContent:(UAZipDownloadContent *)zipDownloadContent {
    UASubscriptionContent *content = zipDownloadContent.userInfo;
    [currentlyDecompressingContent addObject:content.contentKey];
    
    zipDownloadContent.decompressDelegate = self;
    
    zipDownloadContent.decompressedContentPath = [NSString stringWithFormat:@"%@/",
                                                  [self.downloadDirectory stringByAppendingPathComponent:content.subscriptionKey]];
    
    if (self.createProductIDSubdir) {
        
        // Use the content key as the subdirectory unless the
        // product ID is available
        NSString *subdirectory = content.contentKey;
        if ([content.productIdentifier length] > 0) {
            subdirectory = content.productIdentifier;
        }
        
        zipDownloadContent.decompressedContentPath = [NSString stringWithFormat:@"%@/",
                                                      [zipDownloadContent.decompressedContentPath stringByAppendingPathComponent:subdirectory]];
    }
    
    UALOG(@"DecompressedContentPath - '%@",zipDownloadContent.decompressedContentPath);
    
    [zipDownloadContent decompress];
}

- (void)loadDecompressingSubscriptionContent {
    self.decompressingSubscriptionContent = [self loadSubscriptionContentFromFilePath:kDecompressingSubscriptionContentFile];
    if (decompressingSubscriptionContent == nil) {
        self.decompressingSubscriptionContent = [NSMutableArray array];
    }
}

- (void)saveDecompressingSubscriptionContent {
    if (![self saveSubscriptionContent:decompressingSubscriptionContent toFilePath:kDecompressingSubscriptionContentFile]) {
        UALOG(@"Failed to save decompresing products to file path: %@", kDecompressingSubscriptionContentFile);
    }
}

- (BOOL)hasDecompressingSubscriptionContent:(UASubscriptionContent *)subscriptionContent {
    return [decompressingSubscriptionContent containsObject:subscriptionContent.contentKey];
}

- (void)addDecompressingSubscriptionContent:(UASubscriptionContent *)subscriptionContent {
    if (![decompressingSubscriptionContent containsObject:subscriptionContent.contentKey]) {
        [decompressingSubscriptionContent addObject:subscriptionContent.contentKey];
        [self saveDecompressingSubscriptionContent];
    }
}

- (void)removeDecompressingSubscriptionContent:(UASubscriptionContent *)subscriptionContent {
    [decompressingSubscriptionContent removeObject:subscriptionContent.contentKey];
    [self saveDecompressingSubscriptionContent];
}

- (void)resumeDecompressingSubscriptionContent {
    UALOG(@"Resume decompressing subscription content in queue %@", decompressingSubscriptionContent);

    //if the inventory is currently loading the contents will be empty, so there is
    //no point in continuing. log a warning so that it's clear this is the case
    if (![UASubscriptionManager shared].inventory.hasLoaded) {
        UALOG(@"Warning: inventory has not yet loaded, cancelling resume");
        return;
    }

    for (NSString *identifier in decompressingSubscriptionContent) {
        if (![currentlyDecompressingContent containsObject:identifier]) {
            UASubscriptionContent *content = [[UASubscriptionManager shared].inventory contentForKey:identifier];
            if (content) {
                UAZipDownloadContent *zipDownloadContent = [self zipDownloadContentForSubscriptionContent:content];
                [self decompressZipDownloadContent:zipDownloadContent];
            } else {
                UALOG(@"Warning: no subscription content found for pending decompression with identifier %@", identifier);
            }
        }
    }
}

#pragma mark -
#pragma mark Download Fail

- (void)downloadDidFail:(UADownloadContent *)downloadContent {
    UASubscriptionContent *content = [downloadContent userInfo];
	content.progress = 0.0;
    
	// update UI
    [[UASubscriptionManager shared] downloadContentFailed:content];
    [downloadManager endBackground];
}

#pragma mark Download Delegate

- (void)requestDidFail:(UADownloadContent *)downloadContent {
    [self downloadDidFail:downloadContent];
}

- (void)requestDidSucceed:(id)downloadContent {
    if ([downloadContent isKindOfClass:[UAZipDownloadContent class]]) {
        UAZipDownloadContent *zipDownloadContent = (UAZipDownloadContent *)downloadContent;
        
        UASubscriptionContent *subscriptionContent = (UASubscriptionContent *)zipDownloadContent.userInfo;

        [self addDecompressingSubscriptionContent:subscriptionContent];
        [self removePendingSubscriptionContent:subscriptionContent];
        
        [self decompressZipDownloadContent:zipDownloadContent];
        
    } else if ([downloadContent isKindOfClass:[UADownloadContent class]]) {
        [self verifyDidSucceed:downloadContent];
    }
}

#pragma mark -
#pragma mark Decompress Delegate

- (void)decompressDidFail:(UAZipDownloadContent *)downloadContent {
    UASubscriptionContent *content = [downloadContent userInfo];
    [self removeDecompressingSubscriptionContent:content];
    [currentlyDecompressingContent removeObject:content.contentKey];
    [self downloadDidFail:downloadContent];
}

- (void)decompressDidSucceed:(UAZipDownloadContent *)downloadContent {
    UASubscriptionContent *content = [downloadContent userInfo];
    [self removeDecompressingSubscriptionContent:content];
    [currentlyDecompressingContent removeObject:content.contentKey];
    
    UALOG(@"Download Content successful: %@, and decompressed to %@", 
          content.contentName, downloadContent.decompressedContentPath);

    // update subscription
    [[[UASubscriptionManager shared].inventory subscriptionForContent:content] filterDownloadedContents];
    
    // update UI
    [[UASubscriptionManager shared] downloadContentFinished:content];
    [downloadManager endBackground];
}

#pragma mark -
#pragma mark Download Subscription Content

- (void)download:(UASubscriptionContent *)content {
    UALOG(@"verifyContent: %@", content.contentName);
    
    [self addPendingSubscriptionContent:content];

    NSURL *contentURL = [contentURLCache contentForProductURL:content.downloadURL withVersion:[NSNumber numberWithInt:content.revision]];
    if (contentURL) {
        UALOG(@"downloading from cached contentURL: %@", contentURL);
        [self downloadContent:content withContentURL:contentURL];
    } else {
        UADownloadContent *downloadContent = [[[UADownloadContent alloc] init] autorelease];
        downloadContent.username = [UAUser defaultUser].username;
        downloadContent.password = [UAUser defaultUser].password;
        downloadContent.downloadRequestURL = content.downloadURL;
        downloadContent.requestMethod = kRequestMethodPOST;
        downloadContent.userInfo = content;
        [downloadManager download:downloadContent];   
    }
}

#pragma mark -
#pragma mark SubscriptionObserver methods

- (void)userSubscriptionsUpdated:(NSArray *)userSubscriptions {
    [self resumePendingSubscriptionContent];
    [self resumeDecompressingSubscriptionContent];
}


@end
