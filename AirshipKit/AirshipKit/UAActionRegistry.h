/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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
#define kUALandingPageActionDefaultRegistryName @"landing_page_action"
#define kUALandingPageActionDefaultRegistryAlias @"^p"
#define kUADeepLinkActionDefaultRegistryName @"deep_link_action"
#define kUADeepLinkActionDefaultRegistryAlias @"^d"
#define kUAAddCustomEventActionDefaultRegistryName @"add_custom_event_action"
#define kUAShareActionDefaultRegistryName @"share_action"
#define kUAShareActionDefaultRegistryAlias @"^s"
#define kUADisplayInboxActionDefaultRegistryName @"open_mc_action"
#define kUADisplayInboxActionDefaultRegistryAlias @"^mc"
#define kUAOverlayInboxMessageActionDefaultRegistryAlias @"open_mc_overlay_action"
#define kUAOverlayInboxMessageActionDefaultRegistryName @"^mco"
#define kUAPasteboardActionDefaultRegistryName @"clipboard_action"
#define kUAPasteboardActionDefaultRegistryAlias @"^c"
#define kUAWalletActionDefaultRegistryName @"wallet_action"
#define kUAWalletActionDefaultRegistryAlias @"^w"
#define kUACancelSchedulesActionDefaultRegistryName @"cancel_scheduled_actions"
#define kUACancelSchedulesActionDefaultRegistryAlias @"^csa"
#define kUAScheduleActionDefaultRegistryName @"schedule_actions"
#define kUAScheduleActionDefaultRegistryAlias @"^sa"
#define kUAFetchDeviceInfoActionDefaultRegistryName @"fetch_device_info"
#define kUAFetchDeviceInfoActionDefaultRegistryAlias @"^fdi"
#define kUAChannelCaptureActionDefaultRegistryName @"channel_capture_action"
#define kUAChannelCaptureActionDefaultRegistryAlias @"^cc"


#define kUALandingPageActionLastOpenTimeLimitInSeconds @(7 * 86400) // 1 week

NS_ASSUME_NONNULL_BEGIN

/**
 * This class is responsible for runtime-persisting actions and associating
 * them with names and predicates.
 */
@interface UAActionRegistry : NSObject

/**
 * A set of the current registered entries
 */
@property (nonatomic, readonly) NSSet<NSMutableDictionary *> *registeredEntries;

/**
 * Factory method to create an action registry with the default action entries.
 * @return An action registry with the default action entries.
 */
+ (instancetype)defaultRegistry;

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
 * @return `YES` if the action was registered, `NO` if the action was unable to
 * be registered because the name conflicts with a reserved action, the name is
 * nil, or the action is `nil`.
 */
-(BOOL)registerAction:(UAAction *)action
                 name:(NSString *)name
            predicate:(nullable UAActionPredicate)predicate;

/**
 * Registers an action with a predicate.
 *
 * If other entries are registered under any of the specified names, they will
 * be removed from the entry and used for this new action.
 *
 * @param action Action to be performed
 * @param names An array of names for the registry
 * @param predicate A predicate that is evaluated to determine if the
 * action should be performed
 * @return `YES` if the action was registered, `NO` if the action was unable to
 * be registered because one of the names conflicts with a reserved action, 
 * no names were specified, or the action is `nil`.
 */
-(BOOL)registerAction:(UAAction *)action
                 names:(NSArray *)names
            predicate:(nullable UAActionPredicate)predicate;

/**
 * Registers an action.
 *
 * If another entry is registered under specified name, it will be removed from that
 * entry and used for the new action.
 *
 * @param action Action to be performed
 * @param name Name of the action
 * @return `YES` if the action was registered, `NO` if the action was unable to
 * be registered because the name conflicts with a reserved action, the name is 
 * nil, or the action is nil.
 */
-(BOOL)registerAction:(UAAction *)action name:(NSString *)name;


/**
 * Registers an action.
 *
 * If other entries are registered under any of the specified names, they will
 * be removed from the entry and used for this new action.
 *
 * @param action Action to be performed
 * @param names An array of names for the registry
 * @return `YES` if the action was registered, `NO` if the action was unable to
 * be registered because one of the names conflicts with a reserved action,
 * no names were specified, or the action is `nil`.
 */
-(BOOL)registerAction:(UAAction *)action names:(NSArray *)names;


/**
 * Returns a registered action for a given name.
 * 
 * @param name The name of the action
 * @return The UAActionRegistryEntry for the name or alias if registered, 
 * nil otherwise.
 */
-(nullable UAActionRegistryEntry *)registryEntryWithName:(NSString *)name;


/**
 * Adds a situation override action to be used instead of the default
 * registered action for a given situation.  A nil action will cause the entry
 * to be cleared.
 *
 * @param situation The situation to override
 * @param name Name of the registered entry
 * @param action Action to be performed
 * @return `YES` if the action was added to the entry for the situation override.
 * `NO` if the entry is unable to be found with the given name, if the situation
 * is nil, or if the registered entry is reserved.
 */
- (BOOL)addSituationOverride:(UASituation)situation
            forEntryWithName:(NSString *)name
                      action:(nullable UAAction *)action;


/**
 * Updates the predicate for a registered entry.
 *
 * @param predicate Predicate to update or `nil` to clear the current predicate
 * @param name Name of the registered entry
 * @return `YES` if the predicate was updated for the entry. `NO` if the entry
 * is unable to be found with the given name or if the registered entry
 * is reserved.
 */
- (BOOL)updatePredicate:(nullable UAActionPredicate)predicate forEntryWithName:(NSString *)name;

/**
 * Updates the default action for a registered entry.
 *
 * @param action Action to update for the entry
 * @param name Name of the registered entry
 * @return `YES` if the action was updated for the entry. `NO` if the entry
 * is unable to be found with the given name or if the registered entry is 
 * reserved.
 */
- (BOOL)updateAction:(UAAction *)action forEntryWithName:(NSString *)name;

/**
 * Removes a name for a registered entry.
 * 
 * @param name The name to remove
 * @return `YES` if the name was removed from a registered entry. `NO` if the 
 * name is a reserved action name and is unable to be removed.
 */
- (BOOL)removeName:(NSString *)name;


/**
 * Removes an entry and all of its registered names.
 *
 * @param name The name of the entry to remove.
 * @return `YES` if the entry was removed from a registry. `NO` if the
 * entry is a reserved action and is unable to be removed.
 */
- (BOOL)removeEntryWithName:(NSString *)name;


/**
 * Adds a name to a registered entry.
 *
 * @param name The name to add to the registered entry.
 * @param entryName The name of registered entry.
 * @return `YES` if the name was added to the entry.  `NO` if
 * no entry was found for 'entryName', the entry is reserved, or the name 
 * is already used for a reserved entry.
 */
- (BOOL)addName:(NSString *)name forEntryWithName:(NSString *)entryName;

@end

NS_ASSUME_NONNULL_END
