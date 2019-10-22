/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModuleLoader.h"
#import "UAPreferenceDataStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Internal location module loader factory.
 */
@protocol UALocationModuleLoaderFactory <NSObject>

@required

/**
 * Factory method to provide the location module loader.
 * @param dataStore The datastore.
 * @return A location module loader.
 */
+ (id<UAModuleLoader>)locationModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore;

@end

NS_ASSUME_NONNULL_END

