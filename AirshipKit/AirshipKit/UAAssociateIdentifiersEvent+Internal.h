/* Copyright 2017 Urban Airship and Contributors */

#import "UAEvent.h"
#import "UAAssociatedIdentifiers.h"

@interface UAAssociateIdentifiersEvent : UAEvent

/**
 * Factory method to create a UAAssociateIdentifiersEvent.
 * @return A UAAssociatedIdentifiersEvent instance.
 */
+ (instancetype)eventWithIDs:(UAAssociatedIdentifiers *)identifiers;

@end
