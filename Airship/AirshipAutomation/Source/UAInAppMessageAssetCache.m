/* Copyright Airship and Contributors */

#import "UAInAppMessageAssetCache+Internal.h"
#import "UAInAppMessageAssets+Internal.h"
#import "UAAirshipAutomationCoreImport.h"


@interface UAInAppMessageAssetCache()

@property (nonatomic, strong) NSURL *rootURL;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UAInAppMessageAssets *> *activeAssets;

@end

@implementation UAInAppMessageAssetCache

+ (instancetype)assetCache {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.rootURL = [self assetCacheRootURL];
        self.activeAssets = [NSMutableDictionary dictionary];
    }
    
    if (self.rootURL) {
        return self;
    } else {
        return nil;
    }
}

- (UAInAppMessageAssets *)assetsForScheduleId:(NSString *)scheduleId {
    @synchronized (self.activeAssets) {
        if (!self.activeAssets[scheduleId]) {
            UAInAppMessageAssets *assets = [UAInAppMessageAssets assets:[self.rootURL URLByAppendingPathComponent:scheduleId]];
            self.activeAssets[scheduleId] = assets;
        }
        return self.activeAssets[scheduleId];
    }
}

- (void)clearAllAssets {
    // clear each of the assets instance
    @synchronized (self.activeAssets) {
        [self.activeAssets enumerateKeysAndObjectsUsingBlock:^(id scheduleId, id assets, BOOL* stop) {
            [(UAInAppMessageAssets *)assets clearAssets];
        }];
        
        // clear our dictionary of asset instances
        self.activeAssets = [NSMutableDictionary dictionary];

        // remove the contents of the root cache directory
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *rootPath = [self.rootURL path];
        NSArray *fileArray = [fileManager contentsOfDirectoryAtPath:rootPath error:nil];
        for (NSString *filename in fileArray)  {
            [fileManager removeItemAtPath:[rootPath stringByAppendingPathComponent:filename] error:NULL];
        }
    }
}

- (void)releaseAssets:(NSString *)scheduleId wipeFromDisk:(BOOL)wipeFromDisk {
    @synchronized (self.activeAssets) {
        if (wipeFromDisk) {
            UAInAppMessageAssets *assets = [self assetsForScheduleId:scheduleId];
            [assets clearAssets];
        }
        [self.activeAssets removeObjectForKey:scheduleId];
    }
}

#pragma mark -
#pragma mark Utilities
- (NSURL *)assetCacheRootURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    NSString *assetCachePath = [cacheDirectory stringByAppendingPathComponent:@"com.urbanairship.iamassetcache"];
    
    // Does cache directory already exist?
    BOOL isDirectory;
    if ([fileManager fileExistsAtPath:assetCachePath isDirectory:&isDirectory]) {
        if (isDirectory) {
            return [NSURL fileURLWithPath:assetCachePath];
        }
        UA_LERR(@"%@ exists, but is not a directory",assetCachePath);
        NSError *error;
        [fileManager removeItemAtPath:assetCachePath error:&error];
        if (error) {
            UA_LERR(@"Error %@ removing file %@", error, assetCachePath);
            return nil;
        }
    }
    
    // Cache directory does not exist - create it
    NSError *error;
    [fileManager createDirectoryAtPath:assetCachePath withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        UA_LERR(@"Error %@ creating directory %@", error, assetCachePath);
        return nil;
    }
    return [NSURL fileURLWithPath:assetCachePath];
}

@end
