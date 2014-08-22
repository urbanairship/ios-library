#import <Foundation/Foundation.h>

/**
 * The default set of user notification categories.
 */
@interface UADefaultUserNotificationCategories : NSObject

/**
 * Factory method to create the default set of user notification categories.
 * Background user notification actions will default to requiring authorization.
 */
+ (NSSet *)defaultCategories;


/**
 * Factory method to create the default set of user notification categories.
 *
 * @param requireAuth If background actions should default to requiring authorization or not.
 */
+ (NSSet *)defaultCategoriesRequireAuth:(BOOL)requireAuth;

@end
