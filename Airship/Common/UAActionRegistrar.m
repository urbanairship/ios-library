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

#import "UAActionRegistrar+Internal.h"
#import "UAActionRegistryEntry+Internal.h"
#import "UAIncomingPushAction.h"
#import "UAIncomingRichPushAction.h"
#import "UAOpenExternalURLAction.h"

@implementation UAActionRegistrar


SINGLETON_IMPLEMENTATION(UAActionRegistrar)

- (id)init {
    self = [super init];
    if (self) {
        self.registeredActionEntries = [[NSMutableDictionary alloc] init];
        self.aliases = [[NSMutableDictionary alloc] init];

        [self registerDefaultActions];
    }
    return self;
}

- (void)registerAction:(UAAction *)action name:(NSString *)name alias:(NSString *)alias {
    [self registerAction:action name:name alias:alias predicate:nil];
}

- (void)registerAction:(UAAction *)action name:(NSString *)name predicate:(UAActionPredicate)predicate {
    [self registerAction:action name:name alias:nil predicate:predicate];
}

- (void)registerAction:(UAAction *)action name:(NSString *)name {
    [self registerAction:action name:name alias:nil predicate:nil];
}

- (void)registerAction:(UAAction *)action name:(NSString *)name alias:(NSString *)alias predicate:(UAActionPredicate)predicate {
    // Clear any previous entries for the name
    [self clearRegistryForName:name];
    [self clearAlias:name];

    // Clear any entries that registered under the name of the new alias
    [self clearRegistryForName:alias];
    [self clearAlias:alias];

    // Register the action if we actually have an action
    if (action) {
        id newEntry = [UAActionRegistryEntry entryForAction:action name:name
                                                      alias:alias predicate:predicate];
        [self.registeredActionEntries setValue:newEntry forKey:name];

        if (alias) {
            [self.aliases setValue:name forKey:alias];
        }
    }
}

- (UAActionRegistryEntry *)registryEntryForName:(NSString *)name {
    UAActionRegistryEntry *entry = [self.registeredActionEntries valueForKey:name];
    if (!entry) {
        NSString *nameFromAlias = [self.aliases valueForKey:name];
        if (nameFromAlias) {
            entry = [self.registeredActionEntries valueForKey:nameFromAlias];
        }
    }
    return entry;
}

- (NSArray *)registeredEntries {
    NSMutableDictionary *entries = [NSMutableDictionary dictionaryWithDictionary:self.registeredActionEntries];
    [entries removeObjectsForKeys:kUAReservedActionKeys];
    return [entries allValues];
}

- (void)registerDefaultActions {
    // Incoming push action
    UAIncomingPushAction *incomingPushAction = [[UAIncomingPushAction alloc] init];
    [self registerAction:incomingPushAction name:kUAIncomingPushActionRegistryName];

    // Incoming RAP action
    UAIncomingRichPushAction *richPushAction = [[UAIncomingRichPushAction alloc] init];
    [self registerAction:richPushAction name:kUAIncomingRichPushActionRegistryName];

    // Open external URL action
    UAOpenExternalURLAction *urlAction = [[UAOpenExternalURLAction alloc] init];
    [self registerAction:urlAction
                    name:kUAOpenExternalURLActionDefaultRegistryName
                   alias:kUAOpenExternalURLActionDefaultRegistryAlias];
}

- (void)clearRegistryForName:(NSString *)name {
    if (!name) {
        return;
    }

    UAActionRegistryEntry *previousEntry = [self.registeredActionEntries valueForKey:name];
    if (previousEntry) {
        if (previousEntry.alias) {
            [self.aliases setValue:nil forKey:previousEntry.alias];
        }

        [self.registeredActionEntries setValue:nil forKey:name];
    }
}

- (void)clearAlias:(NSString *)alias {
    if (!alias) {
        return;
    }

    UAActionRegistryEntry *entry = [self registryEntryForName:alias];
    if (entry) {
        entry.alias = nil;
    }
    [self.aliases setValue:nil forKey:alias];
}

@end
