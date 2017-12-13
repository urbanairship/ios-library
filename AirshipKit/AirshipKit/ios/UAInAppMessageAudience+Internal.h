/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageAudience.h"


NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageAudienceBuilder()

/**
 * The new user flag.
 */
@property(nonatomic, copy) NSNumber *isNewUser;

@end

@interface UAInAppMessageAudience()

/**
 * The new user flag.
 */
@property(nonatomic, strong) NSNumber *isNewUser;

@end

NS_ASSUME_NONNULL_END
