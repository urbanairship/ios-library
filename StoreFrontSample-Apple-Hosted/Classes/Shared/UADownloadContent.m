/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
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

#import "UADownloadContent.h"
#import "UA_ZipArchive.h"
#import "UAGlobal.h"
#import "UAUtils.h"


@implementation UADownloadContent

@synthesize progressDelegate;
@synthesize clearBeforeDownload;
@synthesize username;
@synthesize password;

@synthesize downloadFileName;
@synthesize downloadRequestURL;
@synthesize userInfo;
@synthesize postData;
@synthesize requestMethod;
@synthesize responseString;
@synthesize downloadPath;
@synthesize downloadTmpPath;

- (id)init {
    if (self = [super init]) {
        self.userInfo = nil;
        self.progressDelegate = nil;
        self.clearBeforeDownload = NO;
        self.downloadFileName = nil;

        return self;
    }
    
    return nil;
}

- (void)dealloc {
    RELEASE_SAFELY(userInfo);
    RELEASE_SAFELY(username);
    RELEASE_SAFELY(password);
    RELEASE_SAFELY(downloadRequestURL);
    RELEASE_SAFELY(downloadFileName);
    RELEASE_SAFELY(requestMethod);
    RELEASE_SAFELY(responseString);
    RELEASE_SAFELY(downloadPath);
    RELEASE_SAFELY(downloadTmpPath);
    RELEASE_SAFELY(postData);
    
    [super dealloc];
}


- (NSString *)downloadPath {
    if (downloadPath == nil) {
        if ([self downloadFileName] == nil) {
            UALOG(@"download path is nil");
            return nil;
        }
        self.downloadPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat: @"%@.zip", [self downloadFileName]]];
        
        UALOG(@"download path: %@", downloadPath);
    }

    return downloadPath;
}

- (NSString *)downloadTmpPath {
    if (downloadTmpPath == nil) {
        if ([self downloadFileName] == nil) {
            UALOG(@"temp download path is nil");
            return nil;
        }
        self.downloadTmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                            [NSString stringWithFormat: @"%@_tmp.zip", [self downloadFileName]]];
        
        UALOG(@"temp download path: %@", downloadTmpPath);
    }
    return downloadTmpPath;
}

@end

@implementation UAZipDownloadContent
@synthesize decompressDelegate;
@synthesize decompressedContentPath;

#pragma mark -
#pragma mark Decompress Call Back

- (void)dealloc {
    RELEASE_SAFELY(decompressedContentPath);
    [super dealloc];
}

- (void)decompressDidFinish:(UAZipDownloadContent *)downloadContent {
    UALOG("Succeessfully decompressed: %@ to %@", [downloadContent downloadFileName], self.decompressedContentPath);
    if (decompressDelegate && [decompressDelegate respondsToSelector:@selector(decompressDidSucceed:)]) {
        [decompressDelegate decompressDidSucceed:downloadContent];
    }
}

- (void)decompressDidFail:(UAZipDownloadContent *)downloadContent {
    UALOG(@"Failed to decompress: %@", [downloadContent downloadFileName]);
    if (decompressDelegate && [decompressDelegate respondsToSelector:@selector(decompressDidFail:)]) {
        [decompressDelegate decompressDidFail:downloadContent];
    }
}

#pragma mark -
#pragma mark Decompress

- (void)decompress {
    NSString *ext = [[self downloadPath] pathExtension];
    if([ext caseInsensitiveCompare: @"zip"] == NSOrderedSame) {
        // request is retained by newly detached thread
        [NSThread detachNewThreadSelector:@selector(decompressContent) toTarget:self withObject:nil];
    } else {
        UALOG(@"Content must end with .zip extention, ignoring");
        [self decompressDidFail:self];
    }
}

- (void)decompressContent {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    BOOL decompressed = NO;
    NSString *path = [self downloadPath];
    
    UA_ZipArchive *za = [[UA_ZipArchive alloc] init];
    if ([za UnzipOpenFile:path]) {
        
        UALOG(@"Decompressing to %@", self.decompressedContentPath);

        if ([za UnzipFileTo:self.decompressedContentPath overWrite:YES]) {
            
            decompressed = YES;
            
            NSError *error = nil;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            BOOL success = [fileManager removeItemAtPath:path error:&error];
            if (!success) {
                UALOG(@"Failed to remove downloaded item, %@", error);
                decompressed = NO;
            }
            
            //UALOG("Decompressed: %@", [fileManager contentsOfDirectoryAtPath:self.decompressedContentPath error:&error]);
            
        } else {
            UALOG(@"Failed to decompress content %@", path);
            self.decompressedContentPath = nil;
        }

        [za UnzipCloseFile];
    }
    [za release];
    
    // request is retained until after the selector is performed
    SEL selector = @selector(decompressDidFinish:);
    if (!decompressed) {
        selector = @selector(decompressDidFail:);
    }
    [self performSelectorOnMainThread:selector 
                           withObject:self 
                        waitUntilDone:[NSThread isMainThread]];
    [pool release];
}

@end


