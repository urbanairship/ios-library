/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UATestRuntimeConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAAirshipBaseTest : UABaseTest

/**
 * A preference data store unique to this test. The dataStore is created
 * lazily when first used.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * A preference airship with unique appkey/secret. A runtime config is created
 * lazily when first used.
 */
@property (nonatomic, strong) UATestRuntimeConfig *config;

@end

NS_ASSUME_NONNULL_END
