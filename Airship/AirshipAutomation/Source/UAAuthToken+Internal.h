/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object for auth tokens.
 */
@interface UAAuthToken : NSObject

/**
 * The associated channel ID.
 */
@property(nonatomic, readonly) NSString *channelID;

/**
 * The token.
 */
@property(nonatomic, readonly) NSString *token;

/**
 * The expiration date.
 */
@property(nonatomic, readonly) NSDate *expiration;

/**
 * Auth token class factory method.
 *
 * @param channelID The channel ID.
 * @param token The token.
 * @param expiration The expiration date.
 */
+ (instancetype)authTokenWithChannelID:(NSString *)channelID token:(NSString *)token expiration:(NSDate *)expiration;

@end

NS_ASSUME_NONNULL_END
