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
 */
@property (nonatomic, copy, nullable) NSString *deviceAPIURL;

/**
 * The Airship analytics API url.
 */
@property (nonatomic, copy, nullable) NSString *analyticsURL;

/**
 * The Airship remote data url.
 */
@property (nonatomic, copy, nullable) NSString *remoteDataURL;

/**
 * The Airship chat URL.
 */
@property (nonatomic, copy, nullable) NSString *chatURL;

/**
 * The Airship chat web socket URL.
 */
@property (nonatomic, copy, nullable) NSString *chatWebSocketURL;


/**
 * Factory method.
 * @param remoteConfigData the remote config data.
 * @return A remote config.
 */
+ (instancetype)configWithRemoteData:(NSDictionary *)remoteConfigData;

/**
 * Factory method.
 * @param remoteDataURL  The remote data URL.
 * @param deviceAPIURL  The device API URL.
 * @param analyticsURL  The analytics URL.
 * @param chatURL  The chat URL.
 * @param chatWebSocketURL The chat web socket URL.
 * @return A remote config.
 */
+ (instancetype)configWithRemoteDataURL:(nullable NSString *)remoteDataURL
                           deviceAPIURL:(nullable NSString *)deviceAPIURL
                           analyticsURL:(nullable NSString *)analyticsURL
                                chatURL:(nullable NSString *)chatURL
                       chatWebSocketURL:(nullable NSString *)chatWebSocketURL;

@end

NS_ASSUME_NONNULL_END
