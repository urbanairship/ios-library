/* Copyright Urban Airship and Contributors */

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
 * UAComponent initializer.
 *
 * @param dataStore The component's preference data store.
 */
- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Called when the shared UAirship instance is ready.
 * Subclasses can override this method to perform additional setup after initialization.
 *
 * @note This method should not be used externally.
 * @param airship The shared UAirship instance.
 */
- (void)airshipReady:(UAirship *)airship;

/**
 * Determines whether the component is currently enabled.
 *
 * @return `YES` if the component is enabled, otherwise `NO`.
 */
- (BOOL)componentEnabled;

@end

NS_ASSUME_NONNULL_END
