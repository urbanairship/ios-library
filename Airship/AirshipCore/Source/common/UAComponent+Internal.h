/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAComponent.h"
#import "UAPreferenceDataStore+Internal.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const UAAirshipDataOptInKey;

@interface UAComponent()

/**
 * Flag indicating whether the component is enabled. Clear to disable. Set to enable.
 */
@property (assign) BOOL componentEnabled;

/**
 * Component data opt-in flag.
 */
@property (nonatomic, assign, getter=isDataOptIn) BOOL dataOptIn;

@end

NS_ASSUME_NONNULL_END

