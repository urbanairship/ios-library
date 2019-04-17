/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The UASystemVersion class provides system version utilities.
 */
@interface UASystemVersion : NSObject

/**
 * Returns a system version instance.
 */
+ (instancetype)systemVersion;

/**
 * Returns current system version.
 * @return A string for the current system version.
 */
- (NSString *)currentSystemVersion;

/**
 * Compares current system version to provided system version and returns YES if system version
 * is greater than or equal to the provided version, otherwise returns NO.
 *
 * @param version Version string in the following format: major.minor.patch i.e. 11.11.11.
 * @return YES if provided version is equal to greater to system version, otherwise NO..
 */
- (BOOL)isGreaterOrEqualToVersion:(NSString *)version;

@end

NS_ASSUME_NONNULL_END
