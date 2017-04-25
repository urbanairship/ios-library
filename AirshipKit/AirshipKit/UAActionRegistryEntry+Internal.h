/* Copyright 2017 Urban Airship and Contributors */

#import "UAActionRegistryEntry.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * Testing extensions to Action Registry Entry
 */
@interface UAActionRegistryEntry()

///---------------------------------------------------------------------------------------
/// @name Action Registry Entry Internal Properties
///---------------------------------------------------------------------------------------

/**
 * A mutable internal instance of the Entry's names.
 */
@property (nonatomic, strong) NSMutableArray *mutableNames;

///---------------------------------------------------------------------------------------
/// @name Action Registry Entry Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Add a situation override to the UAActionRegistryEntry.
 * @param situation The situation override to add.
 * @param action The action to be added.
 */
- (void)addSituationOverride:(UASituation)situation withAction:(UAAction *)action;

@end

NS_ASSUME_NONNULL_END
