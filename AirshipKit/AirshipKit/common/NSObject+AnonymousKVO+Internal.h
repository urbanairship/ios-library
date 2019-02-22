/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UADisposable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Typedef for blocks passing KVO values.
 */
typedef void (^UAAnonymousKVOBlock)(id value);

/**
 * Observer class facilitating block-based KVO.
 */
@interface UAAnonymousObserver : NSObject

/**
 * The object being observed.
 */
@property (nonatomic, strong, readonly) id object;
/**
 * The block to be executed when the observed object passes new values.
 */
@property (nonatomic, strong, readonly) UAAnonymousKVOBlock block;

/**
 * Observe an object for KVO changes. New values will be passed
 * directly to the provided block.
 *
 * @param object The object to observe.
 * @param keyPath The desired key path.
 * @param block A block that will be executed when the object passes new values.
 */
- (void)observe:(id)object atKeypath:(NSString *)keyPath withBlock:(UAAnonymousKVOBlock)block;

@end

@interface NSObject(AnonymousKVO)

/**
 * A set of anonymous observers.
 */
@property (nonatomic, strong, readonly) NSMutableSet *anonymousObservers;

/**
 * Observe the object for KVO changes. New values will be passed
 * directly to the provided block.
 *
 * @param keyPath the desired key path.
 * @param block A block that will be executed when the object passes new values.
 * @return A UADisposable used for cancellation.
 */
- (UADisposable *)observeAtKeyPath:(NSString *)keyPath withBlock:(UAAnonymousKVOBlock)block;

@end

NS_ASSUME_NONNULL_END
