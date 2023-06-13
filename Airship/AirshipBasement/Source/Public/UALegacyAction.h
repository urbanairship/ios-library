/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Action protocol for obj-c based actions.
 * @note For internal use only. :nodoc:
 */
@protocol UALegacyAction <NSObject>

@property (readonly, nullable) BOOL (^defaultPredicate)(_Nullable id, NSInteger);
@property (readonly, nonnull) NSArray<NSString *> *defaultNames;

- (BOOL)acceptsArgumentValue:(nullable id)arguments situation:(NSInteger)situation;

- (void)performWithArgumentValue:(nullable id)argument
                       situation:(NSInteger)situation
                    pushUserInfo:(nullable NSDictionary *)pushUserInfo
               completionHandler:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
