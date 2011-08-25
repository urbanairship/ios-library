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

#import "UANewsstandHelper.h"

#import "UASubscriptionInventory.h"
#import "UASubscription.h"

#import "UASubscriptionManager.h"
#import "UASubscriptionContent.h"

#import "UADownloadContent.h"
#import "UASubscriptionDownloadManager.h"

#import "UAGlobal.h"
#import "UAUser.h"
#import "UAUtils.h"

@implementation UANewsstandHelper

@synthesize contentIdentifier;

- (id)init {
    if ((self = [super init])) {
        return self;
    }
    return nil;
}

- (void)dealloc {
    [[UASubscriptionManager shared] removeObserver:self];
    
    self.contentIdentifier = nil;
    
    RELEASE_SAFELY(connection);
    
}

#pragma mark -
#pragma mark Push Handler
- (void)handleNewsstandPushInfo:(NSDictionary *)userInfo {
    
    NSDictionary *apsInfo = [userInfo objectForKey:@"aps"];
    if ([[apsInfo objectForKey:@"content-available"] intValue] == 1) {
        // It's a Newsstand app
        
        if ([apsInfo objectForKey:@"badge"] != nil){
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[[apsInfo objectForKey:@"badge"] intValue]];
        }
    }
    
    if ([userInfo objectForKey:@"cid"] != nil) {
        self.contentIdentifier = [userInfo objectForKey:@"cid"];
        
        // reload inventory if necessary
        if ([[UASubscriptionManager shared].inventory hasLoaded]) { 
            [[UASubscriptionManager shared] loadSubscription];
        }
    }
}

#pragma mark -
#pragma mark Subscription Observer
- (void)userSubscriptionsUpdated:(NSArray *)userSubscriptions {
    
    UASubscriptionInventory *inv = [UASubscriptionManager shared].inventory;
    UASubscriptionContent *content = [inv contentForKey:self.contentIdentifier];
    
    if (content) {
        
        NKLibrary *library = [NKLibrary sharedLibrary];
        UALOG(@"Check the library for priors...");
        
        if(![library issueWithName:content.contentKey]) {
            
            //NKIssue *issue = [library addIssueWithName:content.contentKey date:content.publishDate];
            
            UALOG(@"Retrive S3 Bucket for this URL: %@", content.downloadURL);
            
            UAHTTPRequest *request = [UAHTTPRequest requestWithURLString:[content.downloadURL absoluteString]];
            request.HTTPMethod= @"POST";
            request.username = [UAUser defaultUser].username;
            request.password = [UAUser defaultUser].password;
            
            RELEASE_SAFELY(connection);
            connection = [[UAHTTPConnection connectionWithRequest:request] retain];
            connection.delegate = self;
            
            [connection start];
            
        }
    }
    
}

#pragma mark -
#pragma mark UAHTTPConnectionDelegate delegate

- (void)requestDidSucceed:(UAHTTPRequest *)request
                 response:(NSHTTPURLResponse *)response
             responseData:(NSData *)responseData2 {
    
    UALOG(@"response code: %d", [response statusCode]);
    
    NSString* newStr = [[NSString alloc] initWithData:responseData2
                                             encoding:NSUTF8StringEncoding];
    
    UALOG(@"received content download response: %@",newStr);
    
    NSDictionary *result = (NSDictionary *)[UAUtils parseJSON:newStr];
    NSString *contentURLString = [result objectForKey:@"download_url"];
    
    UALOG(@"DOWNLOAD URL: %@", contentURLString);
    
    UASubscriptionInventory *inv = [UASubscriptionManager shared].inventory;
    UASubscriptionContent *content = [inv contentForKey:self.contentIdentifier];
    
    //reset id
    self.contentIdentifier = nil;
    
    if (content) {
        
        NKLibrary *library = [NKLibrary sharedLibrary];
        UALOG(@"Check the library one last time... %@", library);
        
        
        //DEBUG delete issue first
        
        if(![library issueWithName:content.contentKey]) {
            
            UALOG(@"Downloading content with key: %@", content.contentKey);
            
            NKIssue *issue = [library addIssueWithName:content.contentKey date:content.publishDate];
            
            UALOG(@"Issue %@", issue);
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:contentURLString]
                                                                   cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                               timeoutInterval:30.0];
            
            UALOG(@"request: %@", request);
            
            NKAssetDownload *asset = [issue addAssetWithRequest:request];
            [asset downloadWithDelegate:self];
            
            UALOG(@"Staged download.");
        }
    } else {
        UALOG(@"Already have content.");
    }
    
}

- (void)requestDidFail:(UAHTTPRequest *)request {
    UALOG(@"Failed to get S3 Download URL. Fatal.");
}


#pragma mark -
#pragma mark NSURLConnectionDownloadDelegate
- (void)connectionDidFinishDownloading:(NSURLConnection *)downloadConnection destinationURL:(NSURL *)destinationURL {
    
    NKAssetDownload *asset = [downloadConnection newsstandAssetDownload];

    //save and set downloaded
    UASubscriptionInventory *inv = [UASubscriptionManager shared].inventory;
    UASubscriptionContent *content = [inv contentForKey:asset.issue.name];

    if (!content) {
        UALOG(@"Content not found.");
    }
    
    UAZipDownloadContent *zipDownloadContent = [[UAZipDownloadContent alloc] init];
    zipDownloadContent.decompressDelegate = self;
    zipDownloadContent.userInfo = content;
    zipDownloadContent.downloadPath = [destinationURL relativePath];
    UALOG(@"Unzipping content at %@", zipDownloadContent.downloadPath);
          
    zipDownloadContent.decompressedContentPath = 
        [NSString stringWithFormat:@"%@/", 
         [[UASubscriptionManager shared].downloadManager.downloadDirectory stringByAppendingPathComponent:content.subscriptionKey]];
    
    if ([UASubscriptionManager shared].downloadManager.createProductIDSubdir) {
        
        // Use the content key as the subdirectory unless the
        // product ID is available
        NSString *subdirectory = content.contentKey;
        if ([content.productIdentifier length] > 0) {
            subdirectory = content.productIdentifier;
        }
        
        zipDownloadContent.decompressedContentPath = [NSString stringWithFormat:@"%@/",
                                                      [zipDownloadContent.decompressedContentPath stringByAppendingPathComponent:subdirectory]];
    }
    
    [zipDownloadContent decompress];
    
    UALOG(@"Wrote file to %@", [destinationURL absoluteString]);
}

- (void)connectionDidResumeDownloading:(NSURLConnection *)connection
                     totalBytesWritten:(long long)totalBytesWritten
                    expectedTotalBytes:(long long)expectedTotalBytes {
    
    UALOG(@"didResumeDownloading");
}

- (void)connection:(NSURLConnection *)connection
        didWriteData:(long long)bytesWritten
   totalBytesWritten:(long long)totalBytesWritten
    expectedTotalBytes:(long long)expectedTotalBytes {
    
    UALOG(@"Writing bytes. Total thus far: %lld",totalBytesWritten);
}

#pragma mark -
#pragma mark Unzip Delegate

- (void)decompressDidSucceed:(UAZipDownloadContent *)zipDownloadContent {
    UASubscriptionContent *content = zipDownloadContent.userInfo;
    UALOG(@"Decompress succeeded for content key=%@", content.contentKey);
    
    //set progress to 100% / done
    [content setProgress:1.0];
    
    UALOG(@"DONE!!!!! Unzipped to %@", zipDownloadContent.decompressedContentPath);
    
    RELEASE_SAFELY(zipDownloadContent);
}
- (void)decompressDidFail:(UAZipDownloadContent *)zipDownloadContent {
    UASubscriptionContent *content = zipDownloadContent.userInfo;
    UALOG(@"Decompress failed for content key=%@", content.contentKey);
    
    RELEASE_SAFELY(zipDownloadContent);
}

@end
