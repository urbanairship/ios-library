/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Remote config.
 * @note For internal use only. :nodoc:
 */
@interface UARemoteConfig : NSObject 

/**
 * The Airship device API url.
 *
 */
@property (nonatomic, copy, nullable) NSString *deviceAPIURL;

/**
 * The Airship analytics API url.
 *
 */
@property (nonatomic, copy, nullable) NSString *analyticsURL;

/**
 * The Airship remote data url.
 *
 */
@property (nonatomic, copy, nullable) NSString *remoteDataURL;

/**
 * Factory method.
 * @param remoteConfigData the remote config data.
 * @return A remote config.
 */
+ (instancetype)configWithRemoteData:(NSDictionary *)remoteConfigData;

/**
 * Factory method.
 * @param remoteDataURL  the remote data URL.
 * @param deviceAPIURL  the device API URL.
 * @param analyticsURL  the analytics URL.
 * @return A remote config.
 */
+ (instancetype)configWithRemoteDataURL:(NSString *)remoteDataURL
                           deviceAPIURL:(NSString *)deviceAPIURL
                           analyticsURL:(NSString *)analyticsURL;

@end

NS_ASSUME_NONNULL_END
