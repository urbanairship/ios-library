/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Base class for main SDK components.
 */
NS_SWIFT_NAME(Component)
@protocol UAComponent <NSObject>

/**
 * Flag indicating whether the component is enabled. Clear to disable. Set to enable.
 * @note For internal use only. :nodoc:
 */
@property (assign, getter=isComponentEnabled) BOOL componentEnabled;

@optional

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
 */
- (void)airshipReady;

/**
 * Called to handle `uairship://` deep links. The first component that
 * return `YES` will prevent others from receiving the deep link.
 * @param deepLink The deep link.
 * @return `YES` is the deep link was handled, otherwise `NO`.
 */
- (BOOL)deepLink:(NSURL *)deepLink;

@end

NS_ASSUME_NONNULL_END
