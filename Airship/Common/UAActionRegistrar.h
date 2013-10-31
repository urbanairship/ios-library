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
 * Registers an action with a predicate.
 * 
 * If another entry is registered under specified name, it will be removed from that
 * entry and used for the new action.
 *
 * @param action Action to be performed
 * @param name Name of the action
 * @param predicate A predicate that is evaluated to determine if the
 * action should be performed
 * @return 'YES' if the action was registered, 'NO' if the action was unable to
 * be registered because the name conflicts with a reserved action, the name is
 * nil, or the action is nil.
 */
-(BOOL)registerAction:(UAAction *)action
                 name:(NSString *)name
            predicate:(UAActionPredicate)predicate;



/**
 * Registers an action.
 *
 * If another entry is registered under specified name, it will be removed from that
 * entry and used for the new action.
 *
 * @param action Action to be performed
 * @param name Name of the action
 * @return 'YES' if the action was registered, 'NO' if the action was unable to
 * be registered because the name conflicts with a reserved action, the name is 
 * nil, or the action is nil.
 */
-(BOOL)registerAction:(UAAction *)action name:(NSString *)name;

/**
 * Returns a registered action for a given name.
 * 
 * @param name The name of the action
 * @return The UAActionRegistryEntry for the name or alias if registered, 
 * nil otherwise.
 */
-(UAActionRegistryEntry *)registryEntryWithName:(NSString *)name;


/**
 * Adds a situation override action to be used instead of the default
 * registered action for a given situation.  A nil action will cause the entry
 * to be cleared.
 *
 * @param situation The situation to override
 * @param name Name of the registered entry
 * @param action Action to be performed
 * @return 'YES' if the action was added to the entry for the situation override.
 * 'NO' if the entry is unable to be found with the given name, if the situation
 * is nil, or if the registered entry is reserved.
 */
- (BOOL)addSituationOverride:(NSString *)situation
            forEntryWithName:(NSString *)name action:(UAAction *)action;


/**
 * Updates the predicate for a registered entry.
 *
 * @param predicate Predicate to update or nil to clear the current predicate
 * @param name Name of the registered entry
 * @return 'YES' if the predicate was updated for the entry. 'NO' if the entry
 * is unable to be found with the given name or if the registered entry
 * is reserved.
 */
- (BOOL)updatePredicate:(UAActionPredicate)predicate forEntryWithName:(NSString *)name;

/**
 * Updates the default action for a registered entry.
 *
 * @param action Action to update for the entry
 * @param name Name of the registered entry
 * @return 'YES' if the action was updated for the entry. 'NO' if the entry
 * is unable to be found with the given name or if the registered entry is 
 * reserved.
 */
- (BOOL)updateAction:(UAAction *)action forEntryWithName:(NSString *)name;

/**
 * Removes a name for a registered entry.
 * 
 * @param name The name to remove
 * @return 'YES' if the name was removed from a registered entry. 'NO' if the 
 * name is a reserved action name and is unable to be removed.
 */
- (BOOL)removeName:(NSString *)name;


/**
 * Removes an entry and all of its registered names.
 *
 * @param name The name of the entry to remove.
 * @return 'YES' if the entry was removed from a registery. 'NO' if the
 * entry is a reserved action and is unable to be removed.
 */
- (BOOL)removeEntryWithName:(NSString *)name;


/**
 * Adds a name to a registered entry.
 *
 * @param name The name to add to the registered entry.
 * @param entryName The name of registered entry.
 * @return 'YES' if the name was added to the entry.  'NO' if
 * no entry was found for 'entryName'.
 */
- (BOOL)addName:(NSString *)name forEntryWithName:(NSString *)entryName;

/**
 * An array of the current registered entries
 */
-(NSArray *)registeredEntries;

@end
