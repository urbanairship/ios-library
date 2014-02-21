
#import <Foundation/Foundation.h>

/**
 * Protocol for classes reponsible for managing rich content windows.
 */
@protocol UARichContentWindow <NSObject>

@required

/**
 * Close the associated window.
 * @param animated Indicates whether the transition should be animated.
 */
+ (void)closeWindow:(BOOL)animated;

@end
