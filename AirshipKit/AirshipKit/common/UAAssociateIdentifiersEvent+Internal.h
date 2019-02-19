/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UAEvent.h"
#import "UAAssociatedIdentifiers.h"

@interface UAAssociateIdentifiersEvent : UAEvent

///---------------------------------------------------------------------------------------
/// @name Associated Identifiers Event Internal Factory
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UAAssociateIdentifiersEvent.
 * @return A UAAssociatedIdentifiersEvent instance.
 */
+ (instancetype)eventWithIDs:(UAAssociatedIdentifiers *)identifiers;

@end
