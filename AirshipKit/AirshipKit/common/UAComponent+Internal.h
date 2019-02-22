/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAComponent.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UARemoteConfig+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAComponent()

/**
 * Flag indicating whether the component is enabled. Clear to disable. Set to enable.
 */
@property (assign) BOOL componentEnabled;

@property (readonly, nullable) Class remoteConfigClass;

/**
 * Init method.
 *
 * @param dataStore The preference data store in which to store the component's enable / disable state.
 */
- (instancetype)initWithDataStore:(nullable UAPreferenceDataStore *)dataStore NS_DESIGNATED_INITIALIZER;

/**
 * Called when the component's componentEnabled flag has changed value.
 */
- (void)onComponentEnableChange;

/**
 * Called when a new remote config is available.
 */
- (void)onNewRemoteConfig:(UARemoteConfig *)config;

@end

NS_ASSUME_NONNULL_END

