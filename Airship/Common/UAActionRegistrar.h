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
#import "UAActionRegistryEntry.h"
#import "UAGlobal.h"

#define kUAOpenExternalURLActionDefaultRegistryName @"open_external_url_action"
#define kUAOpenExternalURLActionDefaultRegistryAlias @"^u"
#define kUAAddTagsActionDefaultRegistryName @"add_tags_action"
#define kUAAddTagsActionDefaultRegistryAlias @"^+t"
#define kUARemoveTagsActionDefaultRegistryName @"remove_tags_action"
#define kUARemoveTagsActionDefaultRegistryAlias @"^-t"
#define kUASetTagsActionDefaultRegistryName @"^t"
#define kUASetTagsActionDefaultRegistryAlias @"set_tags_action"

@interface UAActionRegistrar : NSObject

SINGLETON_INTERFACE(UAActionRegistrar);

/**
 * Registers an action with a predicate and an alias.
 * 
 * Previously registered actions with the given name or alias will be overwritten.
 * Registering a nil action will result in any previous actions to be removed from
 * the registrar.
 *
 * @param action Action to be performed
 * @param name Name of the action
 * @param alias Alias of the action
 * @param predicate A predicate that is evaluated to determine if the
 * action should be performed
 */
-(void)registerAction:(UAAction *)action name:(NSString *)name
                alias:(NSString *)alias predicate:(UAActionPredicate)predicate;

/**
 * Registers an action with a predicate.
 *
 * Previously registered actions with the given name will be overwritten.
 * Registering a nil action will result in any previous actions to be removed from
 * the registrar.
 *
 * @param action Action to be performed
 * @param name Name of the action
 * @param predicate A predicate that is evaluated to determine if the
 * action should be performed
 */
-(void)registerAction:(UAAction *)action name:(NSString *)name
            predicate:(UAActionPredicate)predicate;


/**
 * Registers an action with an alias.
 *
 * Previously registered actions with the given name or alias will be overwritten.
 * Registering a nil action will result in any previous actions to be removed from
 * the registrar.
 *
 * @param action Action to be performed
 * @param name Name of the action
 * @param alias Alias of the action
 */
-(void)registerAction:(UAAction *)action name:(NSString *)name
                alias:(NSString *)alias;

/**
 * Registers an action.
 *
 * Previously registered actions with the given name will be overwritten.
 * Registering a nil action will result in any previous actions to be removed from
 * the registrar.
 *
 * @param action Action to be performed
 * @param name Name of the action
 */
-(void)registerAction:(UAAction *)action name:(NSString *)name;

/**
 * Returns a registered action for a given name or alias.
 * 
 * @param name The name or alias of the action
 * @return The UAActionRegistryEntry for the name or alias if registered, 
 * nil otherwise.
 */
-(UAActionRegistryEntry *)registryEntryForName:(NSString *)name;

-(NSArray *)registeredEntries;

@end
