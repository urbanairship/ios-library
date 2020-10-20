/* Copyright Airship and Contributors */

#import "UAActionRegistry.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAActionRegistry
 */
@interface UAActionRegistry ()

///---------------------------------------------------------------------------------------
/// @name Action Registry Internal Properties
///---------------------------------------------------------------------------------------

/**
 * Map of names to action entries
 */
@property (nonatomic, strong) NSMutableDictionary *registeredActionEntries;

/**
 * Registers default actions.
 */
- (void)registerDefaultActions;

@end

NS_ASSUME_NONNULL_END
