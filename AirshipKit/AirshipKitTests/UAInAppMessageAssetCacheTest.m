/* Copyright Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageAssetCache+Internal.h"
#import "UAInAppMessageAssets+Internal.h"

@interface UAInAppMessageAssetCacheTest : UABaseTest

@property (nonatomic, strong) NSString *scheduleId1;
@property (nonatomic, strong) NSString *scheduleId2;
@property (nonatomic, strong) UAInAppMessageAssetCache *assetCache;

@property (nonatomic, strong) id mockAssetsClass;
@property (nonatomic, strong) id mockAssets1;
@property (nonatomic, strong) id mockAssets2;

@end

@implementation UAInAppMessageAssetCacheTest

- (void)setUp {
    self.scheduleId1 = @"test-schedule-id";
    self.scheduleId2 = @"another-test-schedule-id";
    
    self.mockAssets1 = [self mockForClass:[UAInAppMessageAssets class]];
    self.mockAssets2 = [self mockForClass:[UAInAppMessageAssets class]];
    self.mockAssetsClass = [self mockForClass:[UAInAppMessageAssets class]];
    
    // create asset cache
    self.assetCache = [UAInAppMessageAssetCache assetCache];
    XCTAssertNotNil(self.assetCache);
    
    // start with an empty cache 
    [self.assetCache clearAllAssets];
}

- (void)tearDown {
    // clean up asset cache
    [self.assetCache clearAllAssets];

    [super tearDown];
}

/**
 * Test the getAssets() call when there are no UAInAppMessageAssets instances
 * and after one has been created.
 */
- (void)testGetAssets {
    // STUB
    __block NSURL *expectedRootURL1 = [self expectedRootURL:self.scheduleId1];
    
    // EXPECTATIONS
    __block int factoryCallCount = 0;
    [[[self.mockAssetsClass stub] andDo:^(NSInvocation *invocation) {
        factoryCallCount++;
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSURL *rootURL = (__bridge NSURL *)arg;
        UAInAppMessageAssets *assets;
        if ([rootURL isEqual:expectedRootURL1]) {
            assets = self.mockAssets1;
        } else {
            assets = nil;
        }
        [invocation setReturnValue:(void *)&assets];
    }] assets:OCMOCK_ANY];
    
    // TEST
    UAInAppMessageAssets *assets = [self.assetCache assetsForScheduleId:self.scheduleId1];
    XCTAssertNotNil(assets);
    XCTAssertEqual(self.mockAssets1, assets);

    // VERIFY
    XCTAssertEqual(factoryCallCount, 1);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];
    
    // TEST
    assets = [self.assetCache assetsForScheduleId:self.scheduleId1];
    XCTAssertNotNil(assets);
    XCTAssertEqual(self.mockAssets1, assets);
    
    // VERIFY
    XCTAssertEqual(factoryCallCount, 1); // asset instance should have been cached
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];
}

/**
 * Test the getAssets() call when there are two UAInAppMessageAssets instances
 * created to make sure they have different root URLs.
 */
- (void)testAssetsHavePerScheduleRoots {
    // SETUP
    __block NSURL *expectedRootURL1 = [self expectedRootURL:self.scheduleId1];
    __block NSURL *expectedRootURL2 = [self expectedRootURL:self.scheduleId2];
    XCTAssertNotEqualObjects(expectedRootURL1, expectedRootURL2);

    // EXPECTATIONS
    __block NSURL *expectedRootURL = expectedRootURL1;
    __block int factoryCallCount = 0;
    [[[self.mockAssetsClass stub] andDo:^(NSInvocation *invocation) {
        factoryCallCount++;
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSURL *rootURL = (__bridge NSURL *)arg;
        UAInAppMessageAssets *assets;
        if ([rootURL isEqual:expectedRootURL1]) {
            assets = self.mockAssets1;
        } else if ([rootURL isEqual:expectedRootURL2]) {
            assets = self.mockAssets2;
        } else {
            assets = nil;
        }
        [invocation setReturnValue:(void *)&assets];
    }] assets:OCMOCK_ANY];
    
    // TEST
    UAInAppMessageAssets *assets1 = [self.assetCache assetsForScheduleId:self.scheduleId1];
    XCTAssertNotNil(assets1);
    XCTAssertEqualObjects(self.mockAssets1, assets1);

    expectedRootURL = expectedRootURL2;
    UAInAppMessageAssets *assets2 = [self.assetCache assetsForScheduleId:self.scheduleId2];
    XCTAssertNotNil(assets2);
    XCTAssertEqual(self.mockAssets2, assets2);

    // VERIFY
    XCTAssertEqual(factoryCallCount, 2);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];
}

/**
 * Test the clearAllAssets() method calls through to the UAInAppMessageAssets
 * instances clearAssets() methods. Also verify that once clearAllAssets() has
 * returned, another call to it doesn't call through to clearAssets(), as
 * those assets will no longer exist.
 */
- (void)testClearAssets {
    // SETUP
    __block NSURL *expectedRootURL1 = [self expectedRootURL:self.scheduleId1];
    __block NSURL *expectedRootURL2 = [self expectedRootURL:self.scheduleId2];
    
    // EXPECTATIONS
    __block int factoryCallCount = 0;
    [[[self.mockAssetsClass stub] andDo:^(NSInvocation *invocation) {
        factoryCallCount++;
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSURL *rootURL = (__bridge NSURL *)arg;
        UAInAppMessageAssets *assets;
        if ([rootURL isEqual:expectedRootURL1]) {
            assets = self.mockAssets1;
        } else if ([rootURL isEqual:expectedRootURL2]) {
            assets = self.mockAssets2;
        } else {
            assets = nil;
        }
        [invocation setReturnValue:(void *)&assets];
    }] assets:OCMOCK_ANY];
    
    // TEST
    UAInAppMessageAssets *assets1 = [self.assetCache assetsForScheduleId:self.scheduleId1];
    XCTAssertNotNil(assets1);
    XCTAssertEqualObjects(self.mockAssets1, assets1);
    
    UAInAppMessageAssets *assets2 = [self.assetCache assetsForScheduleId:self.scheduleId2];
    XCTAssertNotNil(assets2);
    XCTAssertEqual(self.mockAssets2, assets2);
    
    // VERIFY
    XCTAssertEqual(factoryCallCount, 2);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];

    // EXPECTATIONS
    __block int clearCallCount1 = 0;
    [[[self.mockAssets1 stub] andDo:^(NSInvocation *invocation) {
        clearCallCount1++;
    }] clearAssets];
    
    __block int clearCallCount2 = 0;
    [[[self.mockAssets2 stub] andDo:^(NSInvocation *invocation) {
        clearCallCount2++;
    }] clearAssets];
    
    // TEST - clear
    [self.assetCache clearAllAssets];
    
    // VERIFY
    XCTAssertEqual(factoryCallCount, 2);
    XCTAssertEqual(clearCallCount1, 1);
    XCTAssertEqual(clearCallCount2, 1);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];

    // TEST - clear again - neither clear should be called
    [self.assetCache clearAllAssets];

    // VERIFY
    XCTAssertEqual(factoryCallCount, 2);
    XCTAssertEqual(clearCallCount1, 1);
    XCTAssertEqual(clearCallCount2, 1);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];

    // TEST - create should create new Assets instances
    assets1 = [self.assetCache assetsForScheduleId:self.scheduleId1];
    XCTAssertNotNil(assets1);
    XCTAssertEqual(self.mockAssets1, assets1);
    
    assets2 = [self.assetCache assetsForScheduleId:self.scheduleId2];
    XCTAssertNotNil(assets2);
    XCTAssertEqual(self.mockAssets2, assets2);

    // VERIFY
    XCTAssertEqual(factoryCallCount, 4);
    XCTAssertEqual(clearCallCount1, 1);
    XCTAssertEqual(clearCallCount2, 1);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];
}

- (void)testClearWhenNoAssets {
    // TEST
    [self.assetCache clearAllAssets];
    
    // VERIFY
    [self.mockAssetsClass verify];
}

/**
 * Test the releaseAssets(scheduleId,wipeFromDisk) method calls through to only the respective
 * UAInAppMessageAssets instance's clearAssets() method.
 */
- (void)testReleaseOneSchedulesAssetsAndWipe {
    // SETUP
    __block NSURL *expectedRootURL1 = [self expectedRootURL:self.scheduleId1];
    __block NSURL *expectedRootURL2 = [self expectedRootURL:self.scheduleId2];
    
    // EXPECTATIONS
    __block int factoryCallCount = 0;
    [[[self.mockAssetsClass stub] andDo:^(NSInvocation *invocation) {
        factoryCallCount++;
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSURL *rootURL = (__bridge NSURL *)arg;
        UAInAppMessageAssets *assets;
        if ([rootURL isEqual:expectedRootURL1]) {
            assets = self.mockAssets1;
        } else if ([rootURL isEqual:expectedRootURL2]) {
            assets = self.mockAssets2;
        } else {
            assets = nil;
        }
        [invocation setReturnValue:(void *)&assets];
    }] assets:OCMOCK_ANY];

    // TEST
    UAInAppMessageAssets *assets1 = [self.assetCache assetsForScheduleId:self.scheduleId1];
    XCTAssertNotNil(assets1);
    XCTAssertEqual(self.mockAssets1, assets1);
    
    UAInAppMessageAssets *assets2 = [self.assetCache assetsForScheduleId:self.scheduleId2];
    XCTAssertNotNil(assets2);
    XCTAssertEqual(self.mockAssets2, assets2);
    
    // VERIFY
    XCTAssertEqual(factoryCallCount, 2);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];
    
    // EXPECTATIONS
    __block int clearCallCount1 = 0;
    [[[self.mockAssets1 expect] andDo:^(NSInvocation *invocation) {
        clearCallCount1++;
    }] clearAssets];
    
    __block BOOL inTest = YES;
    [[[self.mockAssets2 stub] andDo:^(NSInvocation *invocation) {
        if (inTest) {
            XCTFail(@"Shouldn't call clearAssets");
        }
    }] clearAssets];
    
    // TEST
    [self.assetCache releaseAssets:self.scheduleId1 wipeFromDisk:YES];
    
    // VERIFY
    XCTAssertEqual(factoryCallCount, 2);
    XCTAssertEqual(clearCallCount1, 1);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];

    inTest = NO;
}

/**
 * Test the releaseAssets(scheduleId,wipeFromDisk) method doesn't call
 * through to the respective UAInAppMessageAssets instance's clearAssets()
 * methods if the wipeFromDisk is `NO`.
 */
- (void)testReleaseOneSchedulesAssetsAndDontWipe {
    // SETUP
    __block NSURL *expectedRootURL1 = [self expectedRootURL:self.scheduleId1];
    __block NSURL *expectedRootURL2 = [self expectedRootURL:self.scheduleId2];
    
    // EXPECTATIONS
    __block int factoryCallCount = 0;
    [[[self.mockAssetsClass stub] andDo:^(NSInvocation *invocation) {
        factoryCallCount++;
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSURL *rootURL = (__bridge NSURL *)arg;
        UAInAppMessageAssets *assets;
        if ([rootURL isEqual:expectedRootURL1]) {
            assets = self.mockAssets1;
        } else if ([rootURL isEqual:expectedRootURL2]) {
            assets = self.mockAssets2;
        } else {
            assets = nil;
        }
        [invocation setReturnValue:(void *)&assets];
    }] assets:OCMOCK_ANY];

    // TEST
    UAInAppMessageAssets *assets1 = [self.assetCache assetsForScheduleId:self.scheduleId1];
    XCTAssertNotNil(assets1);
    XCTAssertEqual(self.mockAssets1, assets1);
    
    UAInAppMessageAssets *assets2 = [self.assetCache assetsForScheduleId:self.scheduleId2];
    XCTAssertNotNil(assets2);
    XCTAssertEqual(self.mockAssets2, assets2);
    
    // VERIFY
    XCTAssertEqual(factoryCallCount, 2);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];
    
    // EXPECTATIONS
    __block BOOL inTest = YES;
    [[[self.mockAssets1 stub] andDo:^(NSInvocation *invocation) {
        if (inTest) {
            XCTFail(@"Shouldn't call clear");
        }
    }] clearAssets];
    [[[self.mockAssets2 stub] andDo:^(NSInvocation *invocation) {
        if (inTest) {
            XCTFail(@"Shouldn't call clear");
        }
    }] clearAssets];

    // TEST
    [self.assetCache releaseAssets:self.scheduleId1 wipeFromDisk:NO];
    
    // VERIFY
    XCTAssertEqual(factoryCallCount, 2);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];
    
    inTest = NO;
}

/**
 * Test the releaseAssets(scheduleId, wipeFromDisk) method calls through
 * to only the respective UAInAppMessageAssets instance's clearAssets()
 * method. It should also work if the schedule is not already active
 */
- (void)testReleaseOneSchedulesAssetsAndWipeWhenAssetsIsntActive {
    // SETUP
    __block NSURL *expectedRootURL1 = [self expectedRootURL:self.scheduleId1];
    __block NSURL *expectedRootURL2 = [self expectedRootURL:self.scheduleId2];
    
    // EXPECTATIONS
    __block int factoryCallCount = 0;
    [[[self.mockAssetsClass stub] andDo:^(NSInvocation *invocation) {
        factoryCallCount++;
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        NSURL *rootURL = (__bridge NSURL *)arg;
        UAInAppMessageAssets *assets;
        if ([rootURL isEqual:expectedRootURL1]) {
            assets = self.mockAssets1;
        } else if ([rootURL isEqual:expectedRootURL2]) {
            assets = self.mockAssets2;
        } else {
            assets = nil;
        }
        [invocation setReturnValue:(void *)&assets];
    }] assets:OCMOCK_ANY];
    
    // EXPECTATIONS
    __block int clearCallCount1 = 0;
    [[[self.mockAssets1 expect] andDo:^(NSInvocation *invocation) {
        clearCallCount1++;
    }] clearAssets];
    
    __block BOOL inTest = YES;
    [[[self.mockAssets2 stub] andDo:^(NSInvocation *invocation) {
        if (inTest) {
            XCTFail(@"Shouldn't call clearAssets");
        }
    }] clearAssets];
    
    // TEST
    [self.assetCache releaseAssets:self.scheduleId1 wipeFromDisk:YES];
    
    // VERIFY
    XCTAssertEqual(factoryCallCount, 1);
    XCTAssertEqual(clearCallCount1, 1);
    [self.mockAssetsClass verify];
    [self.mockAssets1 verify];
    [self.mockAssets2 verify];
    
    inTest = NO;
}

- (NSURL *)expectedRootURL:(NSString *)scheduleId {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirectory = [cachePaths objectAtIndex:0];
    NSString *assetCachePath = [cacheDirectory stringByAppendingPathComponent:@"com.urbanairship.iamassetcache"];
    NSString *scheduleCachePath = [assetCachePath stringByAppendingPathComponent:scheduleId];

    return [NSURL fileURLWithPath:scheduleCachePath];
}

@end
