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

//private methods
@interface UASubscriptionDownloadManager()
- (void)downloadDidFail:(UADownloadContent *)downloadContent;
@end

@implementation UASubscriptionDownloadManager

@synthesize downloadDirectory;
@synthesize createProductIDSubdir;

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

- (void)verifyDidSucceed:(UADownloadContent *)downloadContent {
    UASubscriptionContent *content = downloadContent.userInfo;
    UAZipDownloadContent *zipDownloadContent = [[[UAZipDownloadContent alloc] init] autorelease];
    [zipDownloadContent setUserInfo:content];
    
    id result = [UAUtils parseJSON:downloadContent.responseString];
    NSString *contentURLString = [result objectForKey:@"download_url"];
    UALOG(@"Actual download URL: %@", contentURLString);
    
    if (!contentURLString) {
        UALOG(@"Error: no actual download_url returned from download_url");
        [self downloadDidFail:zipDownloadContent];
        return;
    }

    zipDownloadContent.downloadRequestURL = [NSURL URLWithString:contentURLString];
    zipDownloadContent.downloadFileName = [UAUtils UUID];
    zipDownloadContent.progressDelegate = content;
    zipDownloadContent.requestMethod = kRequestMethodGET;
    [downloadManager download:zipDownloadContent];
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
        zipDownloadContent.decompressDelegate = self;
        
        UASubscriptionContent *subscriptionContent = (UASubscriptionContent *)zipDownloadContent.userInfo;
        zipDownloadContent.decompressedContentPath = [NSString stringWithFormat:@"%@/",
                                                      [self.downloadDirectory stringByAppendingPathComponent:subscriptionContent.subscriptionKey]];

        if (self.createProductIDSubdir && subscriptionContent.productIdentifier) {
            zipDownloadContent.decompressedContentPath = [NSString stringWithFormat:@"%@/",
                                                          [zipDownloadContent.decompressedContentPath stringByAppendingPathComponent:subscriptionContent.productIdentifier]];
        }
        
        
        [zipDownloadContent decompress];
    } else if ([downloadContent isKindOfClass:[UADownloadContent class]]) {
        [self verifyDidSucceed:downloadContent];
    }
}

#pragma mark -
#pragma mark Decompresse Delegate

- (void)decompressDidFail:(UAZipDownloadContent *)downloadContent {
    [self downloadDidFail:downloadContent];
}

- (void)decompressDidSucceed:(UAZipDownloadContent *)downloadContent {
    UASubscriptionContent *content = [downloadContent userInfo];
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
    UADownloadContent *downloadContent = [[[UADownloadContent alloc] init] autorelease];
    downloadContent.username = [UAUser defaultUser].username;
    downloadContent.password = [UAUser defaultUser].password;
    downloadContent.downloadRequestURL = content.downloadURL;
    downloadContent.requestMethod = kRequestMethodPOST;
    downloadContent.userInfo = content;
    [downloadManager download:downloadContent];
}

- (id)init {
    if (!(self = [super init]))
        return nil;
    
    downloadManager = [[UADownloadManager alloc] init];
    downloadManager.delegate = self;
    self.downloadDirectory = kUADownloadDirectory;
    self.createProductIDSubdir = YES;
    
    return self;
}

- (void)dealloc {
    RELEASE_SAFELY(downloadManager);
    RELEASE_SAFELY(downloadDirectory);
    [super dealloc];
}

@end
