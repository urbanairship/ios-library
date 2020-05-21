/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal debug library module loader factory.
 * @note For internal use only. :nodoc:
 */
@protocol UADebugLibraryModuleLoaderFactory <NSObject>

@required

/**
 * Factory method to provide the debug library module loader.
 * @param analytics Analytics instance.
 * @return A module loader.
 */
+ (nonnull id<UAModuleLoader>)debugLibraryModuleLoaderWithAnalytics:(UAAnalytics *)analytics;

@end

NS_ASSUME_NONNULL_END

