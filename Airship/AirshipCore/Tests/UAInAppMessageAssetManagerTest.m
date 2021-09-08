/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageAssetManager+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageAssetCache+Internal.h"
#import "UAAsyncOperation+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@interface UAInAppMessageAssetManagerTest : UABaseTest
@property (nonatomic, strong) UAInAppMessageAssetManager *assetManager;
@property (nonatomic, copy) NSString *mediaURL;

@property (nonatomic, strong) id mockQueue;
@property (nonatomic, strong) id mockPrepareAssetDelegate;
@property (nonatomic, strong) id mockCachePolicyDelegate;
@property (nonatomic, strong) id mockAssetCache;
@property (nonatomic, strong) id mockAssets;
@property (nonatomic, strong) id mockRemoteDataManager;

@end

@implementation UAInAppMessageAssetManagerTest

- (void)setUp {
    self.mockQueue = [self mockForClass:[NSOperationQueue class]];

    // Stub the queue to run UAAsyncOperation immediately
    [[[self.mockQueue stub] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSOperation *operation = (__bridge NSOperation *)arg;
        [operation start];
    }] addOperation:[OCMArg checkWithBlock:^BOOL(id obj) {
        return [obj isKindOfClass:[UAAsyncOperation class]];
    }]];

    self.mockAssetCache = [self mockForClass:[UAInAppMessageAssetCache class]];
    self.mockAssets = [self mockForClass:[UAInAppMessageAssets class]];

    // Create a UAInAppMessageAssetManager
    self.assetManager = [UAInAppMessageAssetManager assetManagerWithAssetCache:self.mockAssetCache operationQueue:self.mockQueue];

    // Get file system URL for test image
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *url = [bundle URLForResource:@"airship" withExtension:@"jpg"];
    self.mediaURL = [url absoluteString];

    self.mockRemoteDataManager = [self mockForClass:[UARemoteDataManager class]];

    // set up asset manager delegates
    self.mockPrepareAssetDelegate = [self mockForProtocol:@protocol(UAInAppMessagePrepareAssetsDelegate)];
    self.assetManager.prepareAssetsDelegate = self.mockPrepareAssetDelegate;
    self.mockCachePolicyDelegate = [self mockForProtocol:@protocol(UAInAppMessageCachePolicyDelegate)];
    self.assetManager.cachePolicyDelegate = self.mockCachePolicyDelegate;
}

/**
 * Test that the onSchedule: method initialize an Assets instance
 * and calls the prepare delegate's onSchedule:assets: when the app
 * specifies cacheOnSchedule = YES.
 */
- (void)testOnScheduleWhenShouldCache {
    UAInAppMessage *message = [self messageWithMediaURL:self.mediaURL];
    NSString *scheduleID = @"some ID";

    [[[self.mockCachePolicyDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] shouldCacheOnSchedule:message];

    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:scheduleID];
    [[self.mockAssetCache expect] releaseAssets:scheduleID wipeFromDisk:NO];
    [[[self.mockPrepareAssetDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(UAInAppMessagePrepareResultSuccess);
    }] onSchedule:message assets:self.mockAssets completionHandler:OCMOCK_ANY];

    [self.assetManager onMessageScheduled:message scheduleID:scheduleID];

    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
 * Test that the onSchedule: method doesn't initialize an Assets instance
 * and doesn't calls the prepare delegate's onSchedule:assets: when the app
 * specifies cacheOnSchedule = YES.
 */
- (void)testOnScheduleWhenDelegateDoesntWantToCache {
    UAInAppMessage *message = [self messageWithMediaURL:self.mediaURL];
    NSString *scheduleID = @"some ID";

    [[[self.mockCachePolicyDelegate expect] andReturnValue:OCMOCK_VALUE(NO)] shouldCacheOnSchedule:message];
    [[[self.mockAssetCache stub] andReturn:self.mockAssets] assetsForScheduleId:OCMOCK_ANY];
    [[self.mockAssetCache reject] assetsForScheduleId:OCMOCK_ANY];
    [[self.mockAssetCache reject] releaseAssets:OCMOCK_ANY wipeFromDisk:NO];
    [[self.mockAssetCache reject] releaseAssets:OCMOCK_ANY wipeFromDisk:YES];
    [[self.mockPrepareAssetDelegate reject] onSchedule:OCMOCK_ANY assets:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.assetManager onMessageScheduled:message scheduleID:scheduleID];

    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];

}

/**
 * Test that the onSchedule: method doesn't initialize an Assets instance
 * and doesn't calls the prepare delegate's onSchedule:assets: when the app
 * doesn't implement the cache policy delegate.
 */
- (void)testOnScheduleNoCachePolicyDelegate {
    self.assetManager.cachePolicyDelegate = nil;

    UAInAppMessage *message = [self messageWithMediaURL:self.mediaURL];
    NSString *scheduleID = @"some ID";

    [[[self.mockAssetCache stub] andReturn:self.mockAssets] assetsForScheduleId:OCMOCK_ANY];
    [[self.mockAssetCache reject] assetsForScheduleId:OCMOCK_ANY];
    [[self.mockAssetCache reject] releaseAssets:OCMOCK_ANY wipeFromDisk:NO];
    [[self.mockAssetCache reject] releaseAssets:OCMOCK_ANY wipeFromDisk:YES];
    [[self.mockPrepareAssetDelegate reject] onSchedule:OCMOCK_ANY assets:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [self.assetManager onMessageScheduled:message scheduleID:scheduleID];

    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
 * Test that the onPrepare: method gets an Assets instance,
 * calls the prepare delegate's onPrepare:assets: and
 * returns the result of that call.
 */
- (void)testOnPrepare {
    UAInAppMessage *message = [self messageWithMediaURL:self.mediaURL];
    NSString *scheduleID = @"some ID";

    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:scheduleID];

    [[[self.mockPrepareAssetDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(UAInAppMessagePrepareResultSuccess);
    }] onPrepare:message assets:self.mockAssets completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.assetManager onPrepareMessage:message scheduleID:scheduleID completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultSuccess);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
 * Test that the onPrepare: method gets an Assets instance,
 * calls the prepare delegate's onPrepare:assets: and
 * returns the result of that call.
 */
- (void)testOnPrepareResultCancel {
    UAInAppMessage *message = [self messageWithMediaURL:self.mediaURL];
    NSString *scheduleID = @"some ID";

    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:scheduleID];

    [[[self.mockPrepareAssetDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(UAInAppMessagePrepareResultCancel);
    }] onPrepare:message assets:self.mockAssets completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.assetManager onPrepareMessage:message scheduleID:scheduleID completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultCancel);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
 * Test that the onPrepare: method gets an Assets instance,
 * calls the prepare delegate's onPrepare:assets: and
 * returns the result of that call.
 */
- (void)testOnPrepareResultRetry {
    UAInAppMessage *message = [self messageWithMediaURL:self.mediaURL];
    NSString *scheduleID = @"some ID";

    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:scheduleID];

    [[[self.mockPrepareAssetDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(UAInAppMessagePrepareResultRetry);
    }] onPrepare:message assets:self.mockAssets completionHandler:OCMOCK_ANY];

    XCTestExpectation *prepareFinished = [self expectationWithDescription:@"prepare finished"];
    [self.assetManager onPrepareMessage:message scheduleID:scheduleID completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, UAInAppMessagePrepareResultRetry);
        [prepareFinished fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
* Test that the onDisplayFinished: method does not clear the assets
* when the app specifies shouldPersistCacheAfterDisplay = YES.
*/
- (void)testOnDisplayFinishedPersistCacheAfterDisplay {
    UAInAppMessage *message = [self messageWithMediaURL:self.mediaURL];
    NSString *scheduleID = @"some ID";

    [[[self.mockCachePolicyDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] shouldPersistCacheAfterDisplay:message];
    [[self.mockAssetCache expect] releaseAssets:scheduleID wipeFromDisk:NO];

    [self.assetManager onDisplayFinished:message scheduleID:scheduleID];

    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
 * Test that the onDisplayFinished: method does clear the assets
 * when the app specifies shouldPersistCacheAfterDisplay = NO.
 */
- (void)testOnDisplayFinishedDontPersistCacheAfterDisplay {
    UAInAppMessage *message = [self messageWithMediaURL:self.mediaURL];
    NSString *scheduleID = @"some ID";

    [[[self.mockCachePolicyDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] shouldPersistCacheAfterDisplay:message];
    [[self.mockAssetCache expect] releaseAssets:scheduleID wipeFromDisk:NO];

    [self.assetManager onDisplayFinished:message scheduleID:scheduleID];

    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
 * Test that the onDisplayFinished: method does clear the assets
 * when the app doesn't implement the cachePolicyDelegate.
 */
- (void)testOnDisplayFinishedDefaultPersistCacheAfterDisplay {
    UAInAppMessage *message = [self messageWithMediaURL:self.mediaURL];
    NSString *scheduleID = @"some ID";

    [[[self.mockCachePolicyDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] shouldPersistCacheAfterDisplay:message];
    [[self.mockAssetCache expect] releaseAssets:scheduleID wipeFromDisk:NO];

    [self.assetManager onDisplayFinished:message scheduleID:scheduleID];

    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
 * Test that the onScheduleFinished: method clears the asset cache.
 */
- (void)testOnScheduleFinished {
    NSString *scheduleID = @"some ID";
    [[self.mockAssetCache expect] releaseAssets:scheduleID wipeFromDisk:YES];
    [self.assetManager onScheduleFinished:scheduleID];
    [self.mockAssetCache verify];
}

/**
 * Test that assetsForSchedule will return the correct assets instance.
 */
- (void)testAssetsForSchedule {
    NSString *scheduleID = @"some ID";

    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:scheduleID];

    // TEST
    XCTestExpectation *callbackCalled = [self expectationWithDescription:@"callback called finished"];
    [self.assetManager assetsForScheduleID:scheduleID completionHandler:^(UAInAppMessageAssets *assets) {
        XCTAssertEqualObjects(assets, self.mockAssets);
        [callbackCalled fulfill];
    }];

    [self waitForTestExpectations];
    [self.mockAssetCache verify];
}

- (UAInAppMessage *)messageWithMediaURL:(NSString *)mediaURL {
    return [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        builder.displayContent = [UAInAppMessageBannerDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageBannerDisplayContentBuilder *builder) {
            builder.heading = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                builder.text = @"Here is a headline!";
            }];

            if (mediaURL) {
                UAInAppMessageMediaInfo *media = [UAInAppMessageMediaInfo mediaInfoWithURL:mediaURL contentDescription:@"Fake image" type:UAInAppMessageMediaInfoTypeImage];
                builder.media = media;
            }

            UAInAppMessageButtonInfo *button = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
                builder.label =  [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
                    builder.text = @"Dismiss";
                }];;
                builder.identifier = @"button";
            }];

            builder.buttons = @[button];
        }];
    }];
}

- (NSURL *)cacheURLforSourceURL:(NSString *)sourceURL andScheduleId:(NSString *)scheduleId {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    NSString *assetCachePath = [cacheDirectory stringByAppendingPathComponent:@"UAIAMAssetCache"];
    NSString *scheduleCachePath = [assetCachePath stringByAppendingPathComponent:scheduleId];
    NSString *sourceURLCachePath = [scheduleCachePath stringByAppendingPathComponent:[UAUtils sha256HashWithString:sourceURL]];

    return [NSURL fileURLWithPath:sourceURLCachePath];
}

@end
