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

@end

NS_ASSUME_NONNULL_END

