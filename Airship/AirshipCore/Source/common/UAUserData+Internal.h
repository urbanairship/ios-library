/* Copyright Airship and Contributors */

#import "UAUserData.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAUserData
 */
@interface UAUserData()

/**
 * UAUserData class factory method.
 *
 * @param username The associated user name.
 * @param password The associated user password.
 */
+ (instancetype)dataWithUsername:(NSString *)username password:(NSString *)password;

@end

NS_ASSUME_NONNULL_END

