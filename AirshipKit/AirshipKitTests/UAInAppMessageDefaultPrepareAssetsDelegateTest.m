//* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageDefaultPrepareAssetsDelegate.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"

@interface UAInAppMessageDefaultPrepareAssetsDelegateTest : UABaseTest

@property (nonatomic, strong) NSURL *mediaURL;
@property (nonatomic, strong) NSURL *bogusMediaURL;
@property (nonatomic, strong) UAInAppMessage *messageWithMedia;
@property (nonatomic, strong) UAInAppMessage *messageWithoutMedia;
@property (nonatomic, strong) UAInAppMessage *messageWithBogusMediaURL;
@property (nonatomic, strong) NSString *assetCachePath;
@property (nonatomic, strong) NSURL *cachedAssetURL;

@property (nonatomic, strong) UAInAppMessageDefaultPrepareAssetsDelegate *delegate;

@property (nonatomic, strong) id mockAssets;

@end

@implementation UAInAppMessageDefaultPrepareAssetsDelegateTest

- (void)setUp {
    // Get file system URLs for test images
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    self.mediaURL = [bundle URLForResource:@"airship" withExtension:@"jpg"];

    // get a temporary file for caching media URL
    NSString *tempDirectory = NSTemporaryDirectory();
    self.assetCachePath = [tempDirectory stringByAppendingPathComponent:@"com.urbanairship.test.iamassetcache"];
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:self.assetCachePath withIntermediateDirectories:YES attributes:nil error:&error];
    XCTAssertNil(error, @"Error creating directory %@ = %@", self.assetCachePath, error);
    self.cachedAssetURL = [[NSURL fileURLWithPath:self.assetCachePath] URLByAppendingPathComponent:@"cached-media"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self.cachedAssetURL path]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[self.cachedAssetURL path] error:&error];
        XCTAssertNil(error, @"Error removing %@ = %@", [self.cachedAssetURL path], error);
    }

    self.messageWithMedia = [self sampleMessageWithMediaURL:self.mediaURL];
    self.messageWithoutMedia = [self sampleMessageWithMediaURL:nil];
    self.bogusMediaURL = [NSURL fileURLWithPath:@"/bogus.media"];
    self.messageWithBogusMediaURL = [self sampleMessageWithMediaURL:self.bogusMediaURL];

    self.mockAssets = [self mockForClass:[UAInAppMessageAssets class]];
    
    self.delegate = [[UAInAppMessageDefaultPrepareAssetsDelegate alloc] init];
}

#pragma mark -
#pragma mark Tests

/**
 * test onSchedule:assets:
 */
- (void)testOnSchedule {
    // EXPECTATIONS
    [[[self.mockAssets expect] andReturn:self.cachedAssetURL] getCacheURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURL *assetURL = obj;
        if (![assetURL isEqual:self.mediaURL]) {
            XCTFail(@"Asset URL ID is not equal to test media URL");
            return NO;
        }
        return YES;
    }]];
    
    // TEST
    XCTestExpectation *onScheduleComplete = [self expectationWithDescription:@"onSchedule completionHandler called"];
    [self.delegate onSchedule:self.messageWithMedia assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultSuccess);
        [onScheduleComplete fulfill];
    }];

    [self waitForTestExpectations];
    
    // VERIFY
    [self.mockAssets verify];
    
    // verify asset was cached
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[self.cachedAssetURL path]]);
    XCTAssertTrue([[NSFileManager defaultManager] contentsEqualAtPath:[self.cachedAssetURL path] andPath:[self.mediaURL path]]);
}

/**
 * test onSchedule:assets: with no assets in message
 */
- (void)testOnScheduleNoAssetsToFetch {
    // EXPECTATIONS
    [[self.mockAssets reject] getCacheURL:OCMOCK_ANY];
    
    // TEST
    XCTestExpectation *onScheduleComplete = [self expectationWithDescription:@"onSchedule completionHandler called"];
    [self.delegate onSchedule:self.messageWithoutMedia assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultSuccess);
        [onScheduleComplete fulfill];
    }];

    [self waitForTestExpectations];
    
    // VERIFY
    [self.mockAssets verify];
    
    // verify nothing was cached
    NSArray *listOfFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.assetCachePath error:nil];
    XCTAssertEqual([listOfFiles count],0);
}

/**
 * test onPrepare:assets:
 */
- (void)testOnPrepare {
    // EXPECTATIONS
    [[[self.mockAssets expect] andReturn:self.cachedAssetURL] getCacheURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURL *assetURL = obj;
        if (![assetURL isEqual:self.mediaURL]) {
            XCTFail(@"Asset URL ID is not equal to test media URL");
            return NO;
        }
        return YES;
    }]];
    
    // TEST
    XCTestExpectation *onPrepareComplete = [self expectationWithDescription:@"onPrepare completionHandler called"];
    [self.delegate onPrepare:self.messageWithMedia assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultSuccess);
        [onPrepareComplete fulfill];
    }];
    
    [self waitForTestExpectations];
    
    // VERIFY
    [self.mockAssets verify];
    
    // verify asset was cached
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[self.cachedAssetURL path]]);
    XCTAssertTrue([[NSFileManager defaultManager] contentsEqualAtPath:[self.cachedAssetURL path] andPath:[self.mediaURL path]]);
}

/**
 * test onPrepare:assets: with no assets in message
 */
- (void)testOnPrepareNoAssetsToFetch {
    // EXPECTATIONS
    [[self.mockAssets reject] getCacheURL:OCMOCK_ANY];
    
    // TEST
    XCTestExpectation *onPrepareComplete = [self expectationWithDescription:@"onPrepare completionHandler called"];
    [self.delegate onPrepare:self.messageWithoutMedia assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultSuccess);
        [onPrepareComplete fulfill];
    }];
    
    [self waitForTestExpectations];

    // VERIFY
    [self.mockAssets verify];

    // verify nothing was cached
    NSArray *listOfFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.assetCachePath error:nil];
    XCTAssertEqual([listOfFiles count],0);
}

/**
 * test onPrepare:assets: when there is an error fetching the asset
 */
- (void)testOnPrepareErrorFetching {
    // EXPECTATIONS
    [[[self.mockAssets expect] andReturn:self.cachedAssetURL] getCacheURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURL *assetURL = obj;
        if (![assetURL isEqual:self.bogusMediaURL]) {
            XCTFail(@"Asset URL ID is not equal to test media URL");
            return NO;
        }
        return YES;
    }]];
    
    // TEST
    XCTestExpectation *onPrepareComplete = [self expectationWithDescription:@"onPrepare completionHandler called"];
    [self.delegate onPrepare:self.messageWithBogusMediaURL assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultCancel);
        [onPrepareComplete fulfill];
    }];
    
    [self waitForTestExpectations];

    // VERIFY
    [self.mockAssets verify];
    
    // verify nothing was cached
    NSArray *listOfFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.assetCachePath error:nil];
    XCTAssertEqual([listOfFiles count],0);
}

/**
 * test onPrepare:assets: when there is an 5XX httpResponse
 */
- (void)testOnPrepare5XXHTTPResponse {
    id mockURLSession = [self mockForClass:[NSURLSession class]];
    [[[mockURLSession stub] andReturn:mockURLSession] sharedSession];
    __block void (^completionHandler)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error);
    id mockDownloadTask = [self mockForClass:[NSURLSessionDownloadTask class]];
    [[[mockURLSession stub] andReturn:mockDownloadTask] downloadTaskWithURL:OCMOCK_ANY completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        completionHandler = obj;
        return YES;
    }]];
    id mockURLResponse = [self mockForClass:[NSHTTPURLResponse class]];
    [[[mockURLResponse stub] andReturnValue:OCMOCK_VALUE(500)] statusCode];
    [[[mockDownloadTask stub] andDo:^(NSInvocation *invocation) {
        completionHandler([NSURL URLWithString:@"does-not-matter"], mockURLResponse, nil);
    }] resume];
    
    // EXPECTATIONS
    [[[self.mockAssets expect] andReturn:self.cachedAssetURL] getCacheURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURL *assetURL = obj;
        if (![assetURL isEqual:self.mediaURL]) {
            XCTFail(@"Asset URL ID is not equal to test media URL");
            return NO;
        }
        return YES;
    }]];
    
    // TEST
    XCTestExpectation *onPrepareComplete = [self expectationWithDescription:@"onPrepare completionHandler called"];
    [self.delegate onPrepare:self.messageWithMedia assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultRetry);
        [onPrepareComplete fulfill];
    }];
    
    [self waitForTestExpectations];

    // VERIFY
    [self.mockAssets verify];
    
    // verify nothing was cached
    NSArray *listOfFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.assetCachePath error:nil];
    XCTAssertEqual([listOfFiles count],0);
}

/**
 * test onPrepare:assets: when there is an non-200 httpResponse
 */
- (void)testOnPrepareNon200HTTPResponse {
    id mockURLSession = [self mockForClass:[NSURLSession class]];
    [[[mockURLSession stub] andReturn:mockURLSession] sharedSession];
    __block void (^completionHandler)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error);
    id mockDownloadTask = [self mockForClass:[NSURLSessionDownloadTask class]];
    [[[mockURLSession stub] andReturn:mockDownloadTask] downloadTaskWithURL:OCMOCK_ANY completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        completionHandler = obj;
        return YES;
    }]];
    id mockURLResponse = [self mockForClass:[NSHTTPURLResponse class]];
    [[[mockURLResponse stub] andReturnValue:OCMOCK_VALUE(401)] statusCode];
    [[[mockDownloadTask stub] andDo:^(NSInvocation *invocation) {
        completionHandler([NSURL URLWithString:@"does-not-matter"], mockURLResponse, nil);
    }] resume];
    
    // EXPECTATIONS
    [[[self.mockAssets expect] andReturn:self.cachedAssetURL] getCacheURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURL *assetURL = obj;
        if (![assetURL isEqual:self.mediaURL]) {
            XCTFail(@"Asset URL ID is not equal to test media URL");
            return NO;
        }
        return YES;
    }]];
    
    // TEST
    XCTestExpectation *onPrepareComplete = [self expectationWithDescription:@"onPrepare completionHandler called"];
    [self.delegate onPrepare:self.messageWithMedia assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultCancel);
        [onPrepareComplete fulfill];
    }];
    
    [self waitForTestExpectations];

    // VERIFY
    [self.mockAssets verify];
    
    // verify nothing was cached
    NSArray *listOfFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.assetCachePath error:nil];
    XCTAssertEqual([listOfFiles count],0);
}

/**
 * test onPrepare:assets: when there is an error removing an existing file in the cache
 */
- (void)testOnPrepareErrorRemovingPreviouslyCachedFile {
    // SETUP
    id mockURLSession = [self mockForClass:[NSURLSession class]];
    [[[mockURLSession stub] andReturn:mockURLSession] sharedSession];
    __block void (^completionHandler)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error);
    id mockDownloadTask = [self mockForClass:[NSURLSessionDownloadTask class]];
    [[[mockURLSession stub] andReturn:mockDownloadTask] downloadTaskWithURL:OCMOCK_ANY completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        completionHandler = obj;
        return YES;
    }]];
    id mockURLResponse = [self mockForClass:[NSHTTPURLResponse class]];
    [[[mockURLResponse stub] andReturnValue:OCMOCK_VALUE(200)] statusCode];
    [[[mockDownloadTask stub] andDo:^(NSInvocation *invocation) {
        completionHandler([NSURL URLWithString:@"does-not-matter"], mockURLResponse, nil);
    }] resume];

    id mockFileManager = [self mockForClass:[NSFileManager class]];
    [[[mockFileManager stub] andReturn:mockFileManager] defaultManager];
    [[[mockFileManager stub] andReturnValue:OCMOCK_VALUE(YES)] fileExistsAtPath:OCMOCK_ANY];
    [[[mockFileManager stub] andCall:@selector(failToRemoveItemAtPath:error:)
                            onObject:self] removeItemAtPath:OCMOCK_ANY error:((NSError *__autoreleasing *)[OCMArg anyPointer])];
    
    // EXPECTATIONS
    [[[self.mockAssets expect] andReturn:self.cachedAssetURL] getCacheURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURL *assetURL = obj;
        if (![assetURL isEqual:self.mediaURL]) {
            XCTFail(@"Asset URL ID is not equal to test media URL");
            return NO;
        }
        return YES;
    }]];
    
    // TEST
    XCTestExpectation *onPrepareComplete = [self expectationWithDescription:@"onPrepare completionHandler called"];
    [self.delegate onPrepare:self.messageWithMedia assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultCancel);
        [onPrepareComplete fulfill];
    }];
    
    [self waitForTestExpectations];

    // VERIFY
    [self.mockAssets verify];
    
    // verify nothing was cached
    [mockFileManager stopMocking];
    NSArray *listOfFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.assetCachePath error:nil];
    XCTAssertEqual([listOfFiles count],0);
}

/**
 * test onPrepare:assets: when there is an error moving the file into the cache
 */
- (void)testOnPrepareErrorMovingFileToCache {
    // SETUP
    id mockURLSession = [self mockForClass:[NSURLSession class]];
    [[[mockURLSession stub] andReturn:mockURLSession] sharedSession];
    __block void (^completionHandler)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error);
    id mockDownloadTask = [self mockForClass:[NSURLSessionDownloadTask class]];
    [[[mockURLSession stub] andReturn:mockDownloadTask] downloadTaskWithURL:OCMOCK_ANY completionHandler:[OCMArg checkWithBlock:^BOOL(id obj) {
        completionHandler = obj;
        return YES;
    }]];
    id mockURLResponse = [self mockForClass:[NSHTTPURLResponse class]];
    [[[mockURLResponse stub] andReturnValue:OCMOCK_VALUE(200)] statusCode];
    [[[mockDownloadTask stub] andDo:^(NSInvocation *invocation) {
        completionHandler([NSURL URLWithString:@"does-not-matter"], mockURLResponse, nil);
    }] resume];
    
    id mockFileManager = [self mockForClass:[NSFileManager class]];
    [[[mockFileManager stub] andReturn:mockFileManager] defaultManager];
    [[[mockFileManager stub] andReturnValue:OCMOCK_VALUE(NO)] fileExistsAtPath:OCMOCK_ANY];
    [[[mockFileManager stub] andCall:@selector(failToMoveItemAtPath:toPath:error:)
                            onObject:self] moveItemAtPath:OCMOCK_ANY toPath:OCMOCK_ANY error:((NSError *__autoreleasing *)[OCMArg anyPointer])];
    
    // EXPECTATIONS
    [[[self.mockAssets expect] andReturn:self.cachedAssetURL] getCacheURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURL *assetURL = obj;
        if (![assetURL isEqual:self.mediaURL]) {
            XCTFail(@"Asset URL ID is not equal to test media URL");
            return NO;
        }
        return YES;
    }]];
    
    // TEST
    XCTestExpectation *onPrepareComplete = [self expectationWithDescription:@"onPrepare completionHandler called"];
    [self.delegate onPrepare:self.messageWithMedia assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultCancel);
        [onPrepareComplete fulfill];
    }];
    
    [self waitForTestExpectations];

    // VERIFY
    [self.mockAssets verify];
    
    // verify nothing was cached
    [mockFileManager stopMocking];
    NSArray *listOfFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.assetCachePath error:nil];
    XCTAssertEqual([listOfFiles count],0);
}

/**
 * test onPrepare:assets: when the assets instance can't generate a cache URL.
 */
- (void)testOnPrepareAssetsCannotGenerateCacheURL {
    // SETUP
    id mockURLSession = [self mockForClass:[NSURLSession class]];
    [[mockURLSession reject] sharedSession];
    [[mockURLSession reject] downloadTaskWithURL:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    // EXPECTATIONS
    [[[self.mockAssets expect] andReturn:nil] getCacheURL:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSURL *assetURL = obj;
        if (![assetURL isEqual:self.mediaURL]) {
            XCTFail(@"Asset URL ID is not equal to test media URL");
            return NO;
        }
        return YES;
    }]];
    
    // TEST
    XCTestExpectation *onPrepareComplete = [self expectationWithDescription:@"onPrepare completionHandler called"];
    [self.delegate onPrepare:self.messageWithMedia assets:self.mockAssets completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultCancel);
        [onPrepareComplete fulfill];
    }];
    
    [self waitForTestExpectations];
    
    // VERIFY
    [self.mockAssets verify];
    
    // verify nothing was cached
    NSArray *listOfFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.assetCachePath error:nil];
    XCTAssertEqual([listOfFiles count],0);
}


#pragma mark -
#pragma mark Utilities

- (UAInAppMessage *)sampleMessageWithMediaURL:(NSURL *)mediaURL {
    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.identifier = @"test identifier";
        builder.actions = @{@"cool": @"story"};
        
        builder.displayContent = [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
            builder.placement = UAInAppMessageBannerPlacementTop;
            builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;
            
            UAInAppMessageTextInfo *heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Here is a headline!";
            }];
            builder.heading = heading;
            
            if (mediaURL) {
                UAInAppMessageMediaInfo *media = [UAInAppMessageMediaInfo mediaInfoWithURL:[mediaURL absoluteString] contentDescription:@"Fake image" type:UAInAppMessageMediaInfoTypeImage];
                builder.media = media;
            }
            
            UAInAppMessageTextInfo *buttonText = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Dismiss";
            }];
            
            UAInAppMessageButtonInfo *button = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
                builder.label = buttonText;
                builder.identifier = @"button";
            }];
            
            builder.buttons = @[button];
        }];
        
        builder.audience = [UAInAppMessageAudience audienceWithBuilderBlock:^(UAInAppMessageAudienceBuilder * _Nonnull builder) {
            builder.locationOptIn = @NO;
        }];
    }];
    
    return message;
}

- (BOOL)failToRemoveItemAtPath:(NSString *)path error:(NSError **)error {
    *error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSURLErrorCannotRemoveFile userInfo:nil];
    return NO;
}

- (BOOL)failToMoveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error {
    *error = [[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSURLErrorCannotMoveFile userInfo:nil];
    return NO;
}

@end
