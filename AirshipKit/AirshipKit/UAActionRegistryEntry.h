/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAction.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An entry in the UAActionRegistry.
 */
@interface UAActionRegistryEntry : NSObject

/**
 * The entry's action.
 */
@property (nonatomic, strong) UAAction *action;

/**
 * The entry's predicate.
 */
@property (nonatomic, copy, nullable) UAActionPredicate predicate;

/**
 * Registered names
 */
@property (nonatomic, readonly) NSArray<NSString *> *names;

/**
 * Returns the action for the situation, or the default action if
 * there are no situation overrides.
 * @param situation The specified UASituation enum value
 * @return UAAction for the situation.
 */
- (UAAction *)actionForSituation:(UASituation)situation;

/**
 * UAActionRegistryEntry class factory method.
 * @param action The entry's action.
 * @param predicate The entry's predicate.
 */
+ (instancetype)entryForAction:(UAAction *)action predicate:(UAActionPredicate)predicate;

@end

NS_ASSUME_NONNULL_END
