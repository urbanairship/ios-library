//* Copyright Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageAssets+Internal.h"

@interface UAInAppMessageAssetsTest : UABaseTest

@property (nonatomic, strong) NSString *assetCachePath;
@property (nonatomic, strong) NSURL *rootURL;
@property (nonatomic, strong) UAInAppMessageAssets *assets;

@end

@implementation UAInAppMessageAssetsTest

- (void)setUp {
    // get a temporary root directory for this assets instance
    NSString *tempDirectory = NSTemporaryDirectory();
    self.assetCachePath = [tempDirectory stringByAppendingPathComponent:@"com.urbanairship.test.iamassetcache"];
    
    [self cleanRootDirectory:self.assetCachePath];
    
    self.rootURL = [NSURL fileURLWithPath:self.assetCachePath];
    
    self.assets = [UAInAppMessageAssets assets:self.rootURL];
    XCTAssertNotNil(self.assets);
}

- (void)tearDown {
    [self cleanRootDirectory:self.assetCachePath];

    [super tearDown];
}

#pragma mark -
#pragma mark Tests

// Fail gracefully when an asset instance is created with a bad root url
- (void)testCreateAssetsBadRootDirectory {
    // SETUP
    NSURL *badRootURL = [NSURL URLWithString:@"/badroot"];
    
    // TEST
    UAInAppMessageAssets *assets = [UAInAppMessageAssets assets:badRootURL];
    
    // VERIFY
    XCTAssertNil(assets);
}

/**
 * Release and re-create the instance should succeed
 */
- (void)testReleaseAndRecreateAssets {
    // SETUP
    self.assets = nil;
    
    // TEST
    self.assets = [UAInAppMessageAssets assets:self.rootURL];
    
    // VERIFY
    XCTAssertNotNil(self.assets);
}

/**
 * Get several cache URLs and make sure they are unique and a part
 * of the provided root
 */
- (void)testGetCacheURL {
    // SETUP
    NSString *sampleURL1AsString = @"https://www.google.com/search?q=urbanairship&safe=active&client=safari&rls=en&tbm=isch&source=iu&ictx=1&fir=Y4M41Ijd3GcO7M%253A%252CGdz9xdMXjS67IM%252C%252Fm%252F0hhrcm4&vet=1&usg=AI4_-kS-qxn0pCq5VU62qEYc3egYAhKA6Q&sa=X&ved=2ahUKEwjc7LmHzO7gAhWEITQIHc2aCC4Q_B0wDXoECAUQEQ#imgrc=Y4M41Ijd3GcO7M:";
    NSURL *sampleURL1 = [NSURL URLWithString:sampleURL1AsString];
    NSString *sampleURL2AsString = @"https://www.google.com/";
    NSURL *sampleURL2 = [NSURL URLWithString:sampleURL2AsString];

    // TEST
    NSURL *cacheURL1 = [self.assets getCacheURL:sampleURL1];
    NSURL *cacheURL2 = [self.assets getCacheURL:sampleURL2];

    // VERIFY
    XCTAssertNotNil(cacheURL1);
    XCTAssertNotNil(cacheURL2);
    XCTAssertNotEqualObjects(cacheURL1, cacheURL2);
    XCTAssertNotEqualObjects(cacheURL1, sampleURL1);
    XCTAssertNotEqualObjects(cacheURL2, sampleURL2);
    
    NSURL *rootURL1 = [cacheURL1 URLByDeletingLastPathComponent];
    NSURL *rootURL2 = [cacheURL2 URLByDeletingLastPathComponent];
    XCTAssertNotNil(rootURL1);
    XCTAssertNotNil(rootURL2);
    XCTAssertEqualObjects(rootURL1, rootURL2);
    XCTAssertEqualObjects([self.rootURL path], [rootURL1 path]);
}

- (void)testClearAssetsNoAssets {
    // TEST
    [self.assets clearAssets];
    
    // VERIFY
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[self.rootURL path]]);
}

- (void)testClearAssetsTwice {
    // TEST
    [self.assets clearAssets];
    
    // VERIFY
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[self.rootURL path]]);

    // TEST
    [self.assets clearAssets];
    
    // VERIFY
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[self.rootURL path]]);
}

- (void)testClearAssetsSomeAssetsAreCached {
    // SETUP
    // Get file system URLs for test images
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *mediaURL = [bundle URLForResource:@"airship" withExtension:@"jpg"];
    NSURL *alternateMediaURL = [bundle URLForResource:@"alternate-airship" withExtension:@"jpg"];

    // get cache URLs for test images
    NSURL *mediaCacheURL = [self.assets getCacheURL:mediaURL];
    NSURL *alternateMediaCacheURL = [self.assets getCacheURL:alternateMediaURL];
    
   // Verify that they aren't currently cached
    XCTAssertFalse([self.assets isCached:mediaURL]);
    XCTAssertFalse([self.assets isCached:alternateMediaURL]);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[mediaCacheURL path]]);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[alternateMediaCacheURL path]]);

    // copy test images to cache
    NSError *error;
    [[NSFileManager defaultManager] copyItemAtURL:mediaURL toURL:mediaCacheURL error:&error];
    XCTAssertNil(error,@"Failed to copy %@ to %@ with error %@",mediaURL, mediaCacheURL, error);
    [[NSFileManager defaultManager] copyItemAtURL:alternateMediaURL toURL:alternateMediaCacheURL error:&error];
    XCTAssertNil(error,@"Failed to copy %@ to %@ with error %@",alternateMediaURL, alternateMediaCacheURL, error);
    
    // Verify that they are currently cached
    XCTAssertTrue([self.assets isCached:mediaURL]);
    XCTAssertTrue([self.assets isCached:alternateMediaURL]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[mediaCacheURL path]]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[alternateMediaCacheURL path]]);

    // TEST
    [self.assets clearAssets];

    // VERIFY
    // Verify that they aren't currently cached
    XCTAssertFalse([self.assets isCached:mediaURL]);
    XCTAssertFalse([self.assets isCached:alternateMediaURL]);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[mediaCacheURL path]]);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[alternateMediaCacheURL path]]);

    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[self.rootURL path]]);
}

- (void)testClearAssetsThenAddAssets {
    // SETUP
    [self.assets clearAssets];
    
    // VERIFY
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:[self.rootURL path]]);
    
    // Get file system URLs for test images
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *mediaURL = [bundle URLForResource:@"airship" withExtension:@"jpg"];
    NSURL *alternateMediaURL = [bundle URLForResource:@"alternate-airship" withExtension:@"jpg"];
    
    // get cache URLs for test images
    NSURL *mediaCacheURL = [self.assets getCacheURL:mediaURL];
    NSURL *alternateMediaCacheURL = [self.assets getCacheURL:alternateMediaURL];
    
    // VERIFY
    XCTAssertNil(mediaCacheURL);
    XCTAssertNil(alternateMediaCacheURL);
}

#pragma mark -
#pragma mark Utilities
- (void)cleanRootDirectory:(NSString *)rootDirectory {
    if ([[NSFileManager defaultManager] fileExistsAtPath:rootDirectory]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:rootDirectory error:&error];
        XCTAssertNil(error, @"Error removing %@ = %@", rootDirectory, error);
    }
}

@end
