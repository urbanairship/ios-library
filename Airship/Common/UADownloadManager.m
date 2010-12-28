/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.
 
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

#import "UADownloadManager.h"
#import "UA_SBJSON.h"
#import "UA_ASIHTTPRequest.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAUtils.h"

// Weak link to this notification since it doesn't exist in iOS 3.x
UIKIT_EXTERN NSString* const UIApplicationDidEnterBackgroundNotification __attribute__((weak_import));

@implementation UADownloadManager

@synthesize delegate;

- (id)init {
    if (!(self = [super init]))
        return nil;
    
    continueDownloadsInBackground = YES;
	
IF_IOS4_OR_GREATER(
				   
        if (&UIApplicationDidEnterBackgroundNotification != NULL) {
			
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(enterBackground)
                                                         name:UIApplicationDidEnterBackgroundNotification
                                                       object:nil];
        }
        
        if (&UIApplicationDidEnterBackgroundNotification != NULL && 
            [[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]) {
            
			bgTask = UIBackgroundTaskInvalid;
			
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(doBackground:)
                                                         name:UIApplicationDidEnterBackgroundNotification 
													   object:nil];
        }
);
    
    networkQueue = [[UA_ASINetworkQueue queue] retain];
    [networkQueue go];
    
    // For tracking group downloads
    downloadNetworkQueue = [[UA_ASINetworkQueue queue] retain];
    downloadNetworkQueue.showAccurateProgress = YES;
    downloadNetworkQueue.downloadProgressDelegate = self;
    downloadNetworkQueue.delegate = self;
    downloadNetworkQueue.queueDidFinishSelector = @selector(downloadNetworkQueueFinished:);
    [downloadNetworkQueue go];
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    RELEASE_SAFELY(downloadNetworkQueue);
    RELEASE_SAFELY(networkQueue);
    
    [super dealloc];
}

#pragma mark -
#pragma mark Download Info

- (UADownloadContent *)getDownloadContent:(UA_ASIHTTPRequest *)request {
    return (UADownloadContent*)[request.userInfo objectForKey:@"content"];
}

- (int)downloadingContentCount {
    return downloadNetworkQueue.requestsCount;
}

- (NSArray *)allDownloadingContents {
    NSMutableArray *downloads = [[[NSMutableArray alloc] init] autorelease];
    
    for (UA_ASIHTTPRequest *request in [downloadNetworkQueue operations]) {
        [downloads addObject:[self getDownloadContent:request]];
    }
    
    return downloads;
}

- (UA_ASIHTTPRequest*)getDownloadRequestByContent:(UADownloadContent *)downloadContent {
    for (UA_ASIHTTPRequest *request in [downloadNetworkQueue operations]) {
        if ([request.downloadDestinationPath isEqualToString:[downloadContent downloadPath]]) {
            return request;
        }
    }
    
    return nil;
}

- (BOOL)isDownloading:(UADownloadContent *)downloadContent {
    UA_ASIHTTPRequest *request = [self getDownloadRequestByContent:downloadContent];
    if (request != nil)
        return YES;
    else
        return NO;
}

- (void)cancel:(UADownloadContent *)downloadContent {
    UA_ASIHTTPRequest *request = [self getDownloadRequestByContent:downloadContent];
    if (request != nil)
        [request cancel];
}

- (void)updateProgressDelegate:(UADownloadContent *)downloadContent {
    UA_ASIHTTPRequest *request = [self getDownloadRequestByContent:downloadContent];
    if (request != nil)
        request.downloadProgressDelegate = downloadContent.progressDelegate;
}

#pragma mark -
#pragma mark ASIRequest Callbacks

- (void)downloadDidFail:(UA_ASIHTTPRequest *)request {
    NSError *error = [request error];
    UADownloadContent *content;
    
    UALOG(@"ERROR: NSError query result: %@", error);
    // will cancle all network requests when enter background in iOS4, in this
    // case, should not finish transaction.
    // when the next time entering foreground, StoreKit will automatically add
    // a transaction to restore this purchasing
    if (error.code == ASIRequestCancelledErrorType) {
        return;
    }
    if (error.code == ASIRequestTimedOutErrorType) {
        BOOL running = YES;
        
IF_IOS4_OR_GREATER(

		if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
			running = NO;
		}

);
		
        if (running) {
            content = [self getDownloadContent:request];
            if (content.retryTime < kMaxRetryTime) {
                content.retryTime++;
                if (delegate && [delegate respondsToSelector:@selector(requestRetryByTimeOut:)]) {
                    [delegate requestRetryByTimeOut:content];
                }
                [self download:content];
                return;
            }
        }
    }
    
    content = [self getDownloadContent:request];
    UALOG(@"Access to content: %@ denied in contentWillDownload", [content downloadFileName]);
    [UAUtils requestWentWrong:request keyword:@"Failure downloading content"];

    if (delegate && [delegate respondsToSelector:@selector(requestDidFail:)]) {
        [delegate requestDidFail:content];
    }
}

- (void)downloadDidFinish:(UA_ASIHTTPRequest *)request {
    if (request.responseStatusCode != 200 && request.responseStatusCode != 206) {
        [self downloadDidFail:request];
        return;
    }
    
    if (request.downloadProgressDelegate) {
        [request.downloadProgressDelegate setProgress:1.0];
    }
    UADownloadContent *content = [self getDownloadContent:request];
    
    content.responseString = request.responseString;
    if (delegate && [delegate respondsToSelector:@selector(requestDidSucceed:)]) {
        [delegate requestDidSucceed:content];
    }
}

#pragma mark -
#pragma mark UA_ASINetworkQueue Progress Delegate

- (void)setProgress:(float)progress {
    if (delegate && [delegate respondsToSelector:@selector(downloadQueueProgress:count:)]) {
        [delegate downloadQueueProgress:progress count:[self downloadingContentCount]];
    }
}

- (void)downloadNetworkQueueFinished:(UA_ASINetworkQueue *)queue {
    [self setProgress:1.0];
    UALOG(@"Download Network Queue finished!");
    
    // reset download queue progress
    [downloadNetworkQueue cancelAllOperations];
}

#pragma mark -
#pragma mark Download

- (void)download:(UADownloadContent *)downloadContent {
    if((downloadContent.downloadFileName != nil) && [self isDownloading:downloadContent]) { 
        UALOG(@"Warning: %@ is downloading.", downloadContent.downloadFileName);
        return;
    }
    
    UA_ASIHTTPRequest *request = [UA_ASIHTTPRequest requestWithURL:[downloadContent downloadRequestURL]];
    
    [request setRequestMethod:[downloadContent requestMethod]];
    [request setUseSessionPersistence:NO];
    [request setShouldRedirect:NO];
    [request setTimeOutSeconds:60];
    request.delegate = self;
    [request setDidFinishSelector:@selector(downloadDidFinish:)];
    [request setDidFailSelector:@selector(downloadDidFail:)];
    request.downloadProgressDelegate = [downloadContent progressDelegate];
    request.userInfo = [NSDictionary dictionaryWithObject:downloadContent forKey:@"content"];
    
    if (downloadContent.username && downloadContent.password) {
        request.username = downloadContent.username;
        request.password = downloadContent.password;
    }
    
    if ([downloadContent.requestMethod isEqual:kRequestMethodPOST] && downloadContent.postData) {
        [request addRequestHeader:@"Content-Type" value: @"application/json"];
        UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
        [request appendPostData:[[writer stringWithObject:[downloadContent postData]] dataUsingEncoding:NSUTF8StringEncoding]];
        [writer release];
    }
    
    if ([downloadContent clearBeforeDownload]) {
        [request removeTemporaryDownloadFile];
    }
    
    if (downloadContent.downloadFileName != nil) {
        [request setAllowResumeForFileDownloads:YES];
        [request setDownloadDestinationPath:downloadContent.downloadPath];
        [request setTemporaryFileDownloadPath:downloadContent.downloadTmpPath];
        [downloadNetworkQueue addOperation:request];
    } else {
        [networkQueue addOperation:request];
    }
    
}

#pragma mark -
#pragma mark Memory management

- (void)enterBackground {
    if(!continueDownloadsInBackground) {
        [downloadNetworkQueue cancelAllOperations];
        [networkQueue cancelAllOperations];
    }
}

- (void)endBackground {
    UIApplication *app = [UIApplication sharedApplication];

IF_IOS4_OR_GREATER(

		if (downloadNetworkQueue.requestsCount == 0 && [app respondsToSelector:@selector(endBackgroundTask:)]) {
            if (bgTask != UIBackgroundTaskInvalid) {
                UALOG(@"End Background Downloads");
                [app endBackgroundTask:bgTask]; // We're done, so end background execution now.
                bgTask = UIBackgroundTaskInvalid;
            }
        }
                       
);

}

- (void)doBackground:(NSNotification *)aNotification {
    
IF_IOS4_OR_GREATER(
				   
        if(continueDownloadsInBackground) {
            UIApplication *app = [UIApplication sharedApplication];
            
            if ([app respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)]) {
                
                bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
                    // Synchronize the cleanup call on the main thread in case
                    // the task actually finishes at around the same time.
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIApplication *app = [UIApplication sharedApplication];
                        if (bgTask != UIBackgroundTaskInvalid) {
                            // We've hit the maximum time and didn't exit before, so end background processing.
                            [app endBackgroundTask:bgTask];
                            bgTask = UIBackgroundTaskInvalid;
                        }
                    });
                }];
            }
        }
				   
);

}

@end
