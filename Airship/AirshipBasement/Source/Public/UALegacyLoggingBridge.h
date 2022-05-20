/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Used to bridge logs from our legacy logging used in obj-c modules to the AirshipCore.AirshipLogger.
 *
 * @note For internal use only. :nodoc:
 */
@interface UALegacyLoggingBridge : NSObject

/**
 * The logger block - log level, log message, fileID, function, line
 */
typedef void (^LoggerBlock)(NSInteger, NSString *, NSString *, NSString *, NSUInteger);

/**
 * Set by Airship during takeOff
 */
@property (class, nonatomic, copy, nullable) LoggerBlock logger;

/**
 * Called by the macros in UAGlobal.h
 */
+ (void)logWithLevel:(NSInteger)level
             message:(NSString *)message
              fileID:(NSString *)fileID
            function:(NSString *)function
                line:(NSUInteger)line;
@end

NS_ASSUME_NONNULL_END
