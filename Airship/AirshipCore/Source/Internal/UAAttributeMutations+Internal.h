/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAttributeMutations.h"

@class UADate;

NS_ASSUME_NONNULL_BEGIN

/**
 Defines changes to perform on channel attributes.
*/
@interface UAAttributeMutations ()

///---------------------------------------------------------------------------------------
/// @name Attribute Mutations Internal Methods
///---------------------------------------------------------------------------------------
///

/**
 The collection of all current mutations comprising a mutations object. Used for mutation compression, conversion into pending mutations and testing.
*/
@property(nonatomic, strong, readonly) NSMutableArray<NSDictionary *> *mutationsPayload;

@end

NS_ASSUME_NONNULL_END
