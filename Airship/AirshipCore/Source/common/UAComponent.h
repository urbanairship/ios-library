/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPreferenceDataStore.h"
#import "UAirship.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Base class for main SDK components.
 */
@interface UAComponent : NSObject

- (instancetype)init NS_UNAVAILABLE;

/**
 * Shared instance.
 *
 * @return The shared instance.
 */
+ (null_unspecified instancetype)shared;

/**
 * Init method.
 * @note For internal use only. :nodoc:
 *
 * @param dataStore The preference data store in which to store the component's enable / disable state.
 */
- (instancetype)initWithDataStore:(nullable UAPreferenceDataStore *)dataStore NS_DESIGNATED_INITIALIZER;

/**
 * Called when the component's componentEnabled flag has changed value.
 * @note For internal use only. :nodoc:
 */
- (void)onComponentEnableChange;

/**
* Called when the data opt-in  flag has changed value.
*/
- (void)onDataOptInEnableChange;

/**
 * Called when remote config is loaded. If no config is available for the component, config will be nil.
 * @note For internal use only. :nodoc:
 *
 * @config The config or nil if no config is available for the module.
 */
- (void)applyRemoteConfig:(nullable id)config;

/**
 * Called when the shared UAirship instance is ready.
 * Subclasses can override this method to perform additional setup after initialization.
 * @note For internal use only. :nodoc:
 *
 * @note This method should not be used externally.
 * @param airship The shared UAirship instance.
 */
- (void)airshipReady:(UAirship *)airship;

/**
 * Determines whether the component is currently enabled.
 * @note For internal use only. :nodoc:
 *
 * @return `YES` if the component is enabled, otherwise `NO`.
 */
- (BOOL)componentEnabled;

@end

NS_ASSUME_NONNULL_END
