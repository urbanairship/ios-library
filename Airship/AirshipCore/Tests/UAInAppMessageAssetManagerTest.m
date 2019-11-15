/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageAssetManager+Internal.h"
#import "UASchedule+Internal.h"
#import "UAScheduleInfo+Internal.h"
#import "UAInAppMessageScheduleInfo+Internal.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageAssetCache+Internal.h"
#import "UARemoteDataManager+Internal.h"
#import "UAUtils+Internal.h"
#import "UAAsyncOperation.h"

@interface UAInAppMessageAssetManagerTest : UABaseTest
@property (nonatomic, strong) UAInAppMessageAssetManager *assetManager;
@property (nonatomic, strong) NSString *mediaURL;
@property (nonatomic, strong) NSString *bogusMediaURL;
@property (nonatomic, strong) UASchedule *scheduleWithMedia;
@property (nonatomic, strong) UASchedule *scheduleWithoutMedia;
@property (nonatomic, strong) UASchedule *scheduleWithInvalidID;
@property (nonatomic, strong) UASchedule *scheduleWithInvalidMediaURL;

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

    // Create test schedules
    UAScheduleInfo *scheduleInfo = [self sampleScheduleInfoWithMediaURL:self.mediaURL];
    self.scheduleWithMedia = [UASchedule scheduleWithIdentifier:@"Schedule With Media" info:scheduleInfo metadata:@{}];
    
    scheduleInfo = [self sampleScheduleInfoWithMediaURL:nil];
    self.scheduleWithoutMedia = [UASchedule scheduleWithIdentifier:@"Schedule Without Media" info:scheduleInfo metadata:@{}];

    scheduleInfo = [self sampleScheduleInfoWithMediaURL:nil];
    self.scheduleWithInvalidID = [UASchedule scheduleWithIdentifier:@"" info:scheduleInfo metadata:@{}];
    
    self.bogusMediaURL = @"file:///BOGUS_URL";
    scheduleInfo = [self sampleScheduleInfoWithMediaURL:self.bogusMediaURL];
    self.scheduleWithInvalidMediaURL = [UASchedule scheduleWithIdentifier:@"Schedule With Invalid Media URL" info:scheduleInfo metadata:@{}];
    
    // set up asset manager delegates
    self.mockPrepareAssetDelegate = [self mockForProtocol:@protocol(UAInAppMessagePrepareAssetsDelegate)];
    self.assetManager.prepareAssetsDelegate = self.mockPrepareAssetDelegate;
    self.mockCachePolicyDelegate = [self mockForProtocol:@protocol(UAInAppMessageCachePolicyDelegate)];
    self.assetManager.cachePolicyDelegate = self.mockCachePolicyDelegate;
}

- (void)tearDown {
    [super tearDown];
}

/**
 * Test that the onSchedule: method initialize an Assets instance
 * and calls the prepare delegate's onSchedule:assets: when the app
 * specifies cacheOnSchedule = YES.
 */
- (void)testOnScheduleWhenShouldCache {
    // SETUP
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // delegate "shouldCacheOnSchedule()" should be called - delegate responds YES
    [[[self.mockCachePolicyDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] shouldCacheOnSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessage *message = obj;
        UAInAppMessage *sourceMessage = ((UAInAppMessageScheduleInfo *)schedule.info).message;
        if (![message isEqual:sourceMessage]) {
            XCTFail(@"Message is not equal to test message");
            return NO;
        }
        return YES;
    }]];

    // assets for this schedule id should be set up
    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }]];
    
    // assets for this schedule id should be released but not cleared
    [[self.mockAssetCache expect] releaseAssets:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }] wipeFromDisk:NO];
    
    // delegate onSchedule:assets: should be called - delegate responds that it prepared successfully
    [[[self.mockPrepareAssetDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(UAInAppMessagePrepareResultSuccess);
    }] onSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessage *message = obj;
        UAInAppMessage *sourceMessage = ((UAInAppMessageScheduleInfo *)self.scheduleWithMedia.info).message;
        if (![message isEqual:sourceMessage]) {
            XCTFail(@"Message is not equal to test message");
            return NO;
        }
        return YES;
    }] assets:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessageAssets *assets = obj;
        if (assets != self.mockAssets) {
            XCTFail(@"Assets is not the correct instance");
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    // TEST
    // call OnSchedule()
    [self.assetManager onSchedule:schedule];
    
    // VERIFY
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
    // SETUP
    UASchedule *schedule = self.scheduleWithMedia;

    // EXPECTATIONS
    // delegate "shouldCacheOnSchedule()" should be called - delegate responds NO
    [[[self.mockCachePolicyDelegate expect] andReturnValue:OCMOCK_VALUE(NO)] shouldCacheOnSchedule:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessage *message = obj;
        UAInAppMessage *sourceMessage = ((UAInAppMessageScheduleInfo *)schedule.info).message;
        if (![message isEqual:sourceMessage]) {
            XCTFail(@"Message is not equal to test message");
            return NO;
        }
        return YES;
    }]];

    // assets for this schedule id should not be set up or released
    [[[self.mockAssetCache reject] andReturn:self.mockAssets] assetsForScheduleId:OCMOCK_ANY];
    [[self.mockAssetCache reject] releaseAssets:OCMOCK_ANY wipeFromDisk:NO];
    [[self.mockAssetCache reject] releaseAssets:OCMOCK_ANY wipeFromDisk:YES];

    // delegate onSchedule:assets:completionHandler: should not be called
    [[self.mockPrepareAssetDelegate reject] onSchedule:OCMOCK_ANY assets:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    // TEST
    // call OnSchedule()
    [self.assetManager onSchedule:schedule];

    // VERIFY
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
    // SETUP
    self.assetManager.cachePolicyDelegate = nil;
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // delegate "shouldCacheOnSchedule()" should be called - delegate responds NO
    [[self.mockCachePolicyDelegate reject] shouldCacheOnSchedule:OCMOCK_ANY];
    
    // assets for this schedule id should not be set up or released
    [[[self.mockAssetCache reject] andReturn:self.mockAssets] assetsForScheduleId:OCMOCK_ANY];
    [[self.mockAssetCache reject] releaseAssets:OCMOCK_ANY wipeFromDisk:NO];
    [[self.mockAssetCache reject] releaseAssets:OCMOCK_ANY wipeFromDisk:YES];

    // delegate onSchedule:assets:completionHandler: should not be called
    [[self.mockPrepareAssetDelegate reject] onSchedule:OCMOCK_ANY assets:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    
    // TEST
    // call OnSchedule()
    [self.assetManager onSchedule:schedule];

    // VERIFY
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
    // SETUP
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // assets for this schedule id should be set up
    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }]];
    
    // delegate onPrepare:assets: should be called - delegate responds that it prepared successfully
    __block UAInAppMessagePrepareResult expectedResult = UAInAppMessagePrepareResultSuccess;
    [[[self.mockPrepareAssetDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(expectedResult);
    }] onPrepare:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessage *message = obj;
        UAInAppMessage *sourceMessage = ((UAInAppMessageScheduleInfo *)self.scheduleWithMedia.info).message;
        if (![message isEqual:sourceMessage]) {
            XCTFail(@"Message is not equal to test message");
            return NO;
        }
        return YES;
    }] assets:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessageAssets *assets = obj;
        if (assets != self.mockAssets) {
            XCTFail(@"Assets is not the correct instance");
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];

    // TEST
    [self.assetManager onPrepare:schedule completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, expectedResult);
    }];
    
    // VERIFY
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
    // SETUP
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // assets for this schedule id should be set up
    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }]];
    
    // delegate onPrepare:assets: should be called - delegate responds with a cancel result
    __block UAInAppMessagePrepareResult expectedResult = UAInAppMessagePrepareResultCancel;
    [[[self.mockPrepareAssetDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(expectedResult);
    }] onPrepare:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessage *message = obj;
        UAInAppMessage *sourceMessage = ((UAInAppMessageScheduleInfo *)self.scheduleWithMedia.info).message;
        if (![message isEqual:sourceMessage]) {
            XCTFail(@"Message is not equal to test message");
            return NO;
        }
        return YES;
    }] assets:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessageAssets *assets = obj;
        if (assets != self.mockAssets) {
            XCTFail(@"Assets is not the correct instance");
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];
    
    // TEST
    [self.assetManager onPrepare:schedule completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, expectedResult);
    }];
    
    // VERIFY
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
    // SETUP
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // assets for this schedule id should be set up
    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }]];
    
    // delegate onPrepare:assets: should be called - delegate responds with a retry result
    __block UAInAppMessagePrepareResult expectedResult = UAInAppMessagePrepareResultRetry;
    [[[self.mockPrepareAssetDelegate expect] andDo:^(NSInvocation *invocation) {
        void (^prepareBlock)(UAInAppMessagePrepareResult);
        [invocation getArgument:&prepareBlock atIndex:4];
        prepareBlock(expectedResult);
    }] onPrepare:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessage *message = obj;
        UAInAppMessage *sourceMessage = ((UAInAppMessageScheduleInfo *)self.scheduleWithMedia.info).message;
        if (![message isEqual:sourceMessage]) {
            XCTFail(@"Message is not equal to test message");
            return NO;
        }
        return YES;
    }] assets:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessageAssets *assets = obj;
        if (assets != self.mockAssets) {
            XCTFail(@"Assets is not the correct instance");
            return NO;
        }
        return YES;
    }] completionHandler:OCMOCK_ANY];
    
    [self.assetManager onPrepare:schedule completionHandler:^(UAInAppMessagePrepareResult result) {
        XCTAssertEqual(result, expectedResult);
    }];
    
    // VERIFY
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
     // SETUP
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // delegate "shouldPersistCacheAfterDisplay()" should be called - delegate responds YES
    [[[self.mockCachePolicyDelegate expect] andReturnValue:OCMOCK_VALUE(YES)] shouldPersistCacheAfterDisplay:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessage *message = obj;
        UAInAppMessage *sourceMessage = ((UAInAppMessageScheduleInfo *)schedule.info).message;
        if (![message isEqual:sourceMessage]) {
            XCTFail(@"Message is not equal to test message");
            return NO;
        }
        return YES;
    }]];
    
    // assets for this schedule id should not be released
    [[self.mockAssetCache expect] releaseAssets:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }] wipeFromDisk:NO];
    
    // TEST
    [self.assetManager onDisplayFinished:schedule];

    // VERIFY
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
    // SETUP
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // delegate "shouldPersistCacheAfterDisplay()" should be called - delegate responds NO
    [[[self.mockCachePolicyDelegate expect] andReturnValue:OCMOCK_VALUE(NO)] shouldPersistCacheAfterDisplay:[OCMArg checkWithBlock:^BOOL(id obj) {
        UAInAppMessage *message = obj;
        UAInAppMessage *sourceMessage = ((UAInAppMessageScheduleInfo *)schedule.info).message;
        if (![message isEqual:sourceMessage]) {
            XCTFail(@"Message is not equal to test message");
            return NO;
        }
        return YES;
    }]];

    // assets for this schedule id should be released
    [[self.mockAssetCache expect] releaseAssets:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }] wipeFromDisk:YES];
    
    // TEST
    [self.assetManager onDisplayFinished:schedule];
    
    // VERIFY
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
    // SETUP
    self.assetManager.cachePolicyDelegate = nil;
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // delegate "shouldCacheOnSchedule()" should not be called
    [[self.mockCachePolicyDelegate reject] shouldCacheOnSchedule:OCMOCK_ANY];
    
    // assets for this schedule id should be released
    [[self.mockAssetCache expect] releaseAssets:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }] wipeFromDisk:YES];
    
    // TEST
    [self.assetManager onDisplayFinished:schedule];
    
    // VERIFY
    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
 * Test that the onScheduleFinished: method clears the asset cache.
 */
- (void)testOnScheduleFinished {
    // SETUP
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // assets for this schedule id should be released and cleared
    [[self.mockAssetCache expect] releaseAssets:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }] wipeFromDisk:YES];
    
    // TEST
    [self.assetManager onScheduleFinished:schedule];

    // VERIFY
    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

/**
 * Test that assetsForSchedule will return the correct assets instance.
 */
- (void)testAssetsForSchedule {
    // SETUP
    UASchedule *schedule = self.scheduleWithMedia;
    
    // EXPECTATIONS
    // assets for this schedule id should be set up
    [[[self.mockAssetCache expect] andReturn:self.mockAssets] assetsForScheduleId:[OCMArg checkWithBlock:^BOOL(id obj) {
        NSString *scheduleId = obj;
        if (![scheduleId isEqual:schedule.identifier]) {
            XCTFail(@"Schedule ID is not equal to test schedule ID");
            return NO;
        }
        return YES;
    }]];
    
    // TEST
    [self.assetManager assetsForSchedule:schedule completionHandler:^(UAInAppMessageAssets *assets) {
        XCTAssertEqualObjects(assets, self.mockAssets);
    }];
    
    // VERIFY
    [self.mockPrepareAssetDelegate verify];
    [self.mockCachePolicyDelegate verify];
    [self.mockAssetCache verify];
    [self.mockAssets verify];
}

- (UAInAppMessageScheduleInfo *)sampleScheduleInfoWithMediaURL:(NSString *)mediaURL {
    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder * _Nonnull builder) {
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
                    UAInAppMessageMediaInfo *media = [UAInAppMessageMediaInfo mediaInfoWithURL:mediaURL contentDescription:@"Fake image" type:UAInAppMessageMediaInfoTypeImage];
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
        builder.message = message;
    }];
    return scheduleInfo;
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
