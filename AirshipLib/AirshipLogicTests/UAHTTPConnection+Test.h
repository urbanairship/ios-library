
#import "UAHTTPConnection.h"

/**
 * Quick and dirty category for faking UAHTTPConnections.
 *
 * For all intents and purposes the class remains "real", but when swizzled, the start method
 * immediately completes with success or failure, depending on the configuration below.
 */
@interface UAHTTPConnection(Test)

/**
 * Cause connections to immediately succeed.
 */
+ (void)succeed;

/**
 * cause connections to immediately fail.
 */
+ (void)fail;

/**
 * Replaces the start method with one that does not perform IO and completes immediately.
 */
+ (void)swizzle;

/**
 * Restores the start method to its original implementation.
 */
+ (void)unSwizzle;

@end
