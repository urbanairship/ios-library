
#import <Foundation/Foundation.h>

/**
 * A block to be executed when a `UADisposable` is disposed.
 */
typedef void (^UADisposalBlock)(void);

/**
 * A convenience class for creating self-referencing cancellation tokens.
 *
 * @note: It is left up to the creator to determine what is disposed of and
 * under what circumstances.  This includes threading and memory management concerns.
 */
@interface UADisposable : NSObject

/**
 * Create a new disposable.
 *
 * @param disposalBlock A `UADisposalBlock` to be executed upon disposal.
 */
+ (instancetype) disposableWithBlock:(UADisposalBlock)disposalBlock;

/**
 * Dispose of associated resources.
 */
- (void)dispose;

@end
