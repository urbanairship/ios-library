/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAComponent.h"
#import "UAPreferenceDataStore+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAComponent()

/**
 * Flag indicating whether the component is enabled. Clear to disable. Set to enable.
 */
@property (assign) BOOL componentEnabled;

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
 * Called when remote config is loaded. If no config is available for the component, config will be nil.
 *
 * @config The config or nil if no config is available for the module.
 */
- (void)applyRemoteConfig:(nullable id)config;

@end

NS_ASSUME_NONNULL_END

