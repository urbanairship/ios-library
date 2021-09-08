/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object for holding user data.
 */
NS_SWIFT_NAME(UserData)
@interface UAUserData : NSObject

/**
 * The user name.
 */
@property (nonatomic, readonly, copy) NSString *username;

/**
 * The password.
 */
@property (nonatomic, readonly, copy) NSString *password;

@end

NS_ASSUME_NONNULL_END
