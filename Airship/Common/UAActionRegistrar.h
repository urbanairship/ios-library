/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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
#import "UAActionEntry.h"
#import "UAGlobal.h"

@interface UAActionRegistrar : NSObject


/**
 * A dictionary containing registered action entries
 */
@property(nonatomic, strong) NSDictionary *registeredEntries;

/**
 * Registers an action with a predicate..
 *
 * @param action Action to be performed
 * @param name Name of the action
 * @param predicate A predicate that is evaluated to determine if the
 * action should be performed
 */
-(void)registerAction:(UAAction *)action forName:(NSString *)name withPredicate:(UAActionPredicate)predicate;

/**
 * Registers an action with a predicate..
 *
 * @param action Action to be performed
 * @param name Name of the action
 */
-(void)registerAction:(UAAction *)action forName:(NSString *)name;

/**
 * Returns a registered action for the name
 * 
 * @param name The name of the action
 * @return The action if an action is registered for that name, nil otherwise.
 */
-(UAAction *)actionForName:(NSString *)name;

@end
