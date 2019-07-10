
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Tracks the adding and removal of scenes.
 */
@interface UASceneTracker : NSObject

/**
 * Class factory method.
 *
 * @param notificationCenter The notification center on which to observe scene-related events.
 */
+ (instancetype)sceneObserver:(NSNotificationCenter *)notificationCenter;

/**
 * The primary window scene.
 *
 * @return The primary window scene, or nil if one could not be found.
 */
- (nullable UIWindowScene *)primaryWindowScene API_AVAILABLE(ios(13.0));

@end

NS_ASSUME_NONNULL_END
