/* Copyright Airship and Contributors */

#import "UAInAppMessageAssets+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@interface UAInAppMessageAssets()

@property (nonatomic, strong) NSURL *rootURL;

@end

@implementation UAInAppMessageAssets

+ (instancetype)assets:(NSURL *)rootURL {
    return [[self alloc] initWithRootURL:rootURL];
}

- (instancetype)initWithRootURL:(NSURL *)rootURL {
    self = [super init];
    if (self) {
        self.rootURL = rootURL;
        
        if (![self createAssetsDirectory]) {
            return nil;
        }
    }
    return self;
}

- (BOOL)assetsDirectoryExists {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self.rootURL path]];
}

- (BOOL)createAssetsDirectory {
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtURL:self.rootURL withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        UA_LERR(@"Unable to create assets directory at %@", self.rootURL);
        return NO;
    }
    return YES;
}

- (nullable NSURL *)getCacheURL:(NSURL *)assetURL {
    if (![self assetsDirectoryExists]) {
        return nil;
    }
    
    NSString *assetFilename = [UAUtils sha256HashWithString:[assetURL absoluteString]];

    NSURL *cacheURL = [self.rootURL URLByAppendingPathComponent:assetFilename];
    
    return cacheURL;
}

- (BOOL)isCached:(NSURL *)assetURL {
    NSURL *cachedURL = [self getCacheURL:assetURL];
    if (!cachedURL) {
        return NO;
    }
    BOOL isCached = [[NSFileManager defaultManager] fileExistsAtPath:[cachedURL path]];
    return isCached;
}

-(void)clearAssets {
    // remove cache directory and its contents
    if ([self assetsDirectoryExists]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtURL:self.rootURL error:&error];
        if (error) {
            UA_LERR(@"Unable to remove assets directory at %@", self.rootURL);
        }
    }
}

@end
