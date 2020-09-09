/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "ACCUserProfile.h"

NS_ASSUME_NONNULL_BEGIN

@interface Accengage : NSObject

/*!
 *  @brief Returns the shared @c ACCUserProfile instance.
 *
 *  @return The shared @c ACCUserProfile instance.
 */

+ (ACCUserProfile *)profile;

@end

NS_ASSUME_NONNULL_END
