
#import "UAUser+Internal.h"

@interface UAUser (Test)

/**
 * Swap out the defaultUserCreated method for one that
 * always returns YES.
 */
+ (void)swizzleDefaultUserCreated;

/**
 * Swap the canonical defaultUserCreated method back in place.
 */
+ (void)unswizzleDefaultUserCreated;

@end
