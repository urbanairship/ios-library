/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "UAAction.h"

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
@property (nonatomic, copy) UAActionPredicate predicate;

/**
 * Registered names
 */
@property (nonatomic, readonly) NSArray *names;


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
