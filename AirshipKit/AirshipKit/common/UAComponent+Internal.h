/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent.h"

@class UAPreferenceDataStore;

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

@end

NS_ASSUME_NONNULL_END

