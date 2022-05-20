/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Used to bridge logs from our legacy logging used in obj-c modules to the AirshipCore.AirshipLogger.
 *
 * @note For internal use only. :nodoc:
 */
@interface UALegacyLoggingBridge : NSObject

typedef NSString * _Nonnull(^UAMessageBlock)(void);

/**
 * The logger block - log level, function, line, message block
 */
typedef void (^UALoggerBlock)(NSInteger, NSString *, NSUInteger, UAMessageBlock);

/**
 * Set by Airship during takeOff
 */
@property (class, nonatomic, copy, nullable) UALoggerBlock logger;

/**
 * Called by the macros in UAGlobal.h
 */
+ (void)logWithLevel:(NSInteger)level
            function:(NSString *)function
                line:(NSUInteger)line
             message:(UAMessageBlock)messageBlock;
@end

NS_ASSUME_NONNULL_END
