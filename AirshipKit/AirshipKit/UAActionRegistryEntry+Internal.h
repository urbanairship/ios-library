/* Copyright 2017 Urban Airship and Contributors */

#import "UAActionRegistryEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAActionRegistryEntry()

@property (nonatomic, strong) NSMutableArray *mutableNames;

/**
 * Add a situation override to the UAActionRegistryEntry.
 * @param situation The situation override to add.
 * @param action The action to be added.
 */
- (void)addSituationOverride:(UASituation)situation withAction:(UAAction *)action;

@end

NS_ASSUME_NONNULL_END
