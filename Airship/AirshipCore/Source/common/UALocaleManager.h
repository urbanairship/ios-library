/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UALocaleManager : NSObject

/**
 * The currentLocale. Setting the currentLocale to nil reverts the locale to the current user’s chosen system locale.
 */
@property (nonatomic, strong, null_resettable) NSLocale *currentLocale;

/**
 * Clear the locale. Reverts the locale to the current user’s chosen system locale.
 */
- (void)clearLocale;

@end

NS_ASSUME_NONNULL_END
