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

#import "UAActionRegistry+Internal.h"
#import "UAActionRegistryEntry+Internal.h"
#import "UAIncomingPushAction.h"
#import "UAIncomingRichPushAction.h"
#import "UAOpenExternalURLAction.h"
#import "UAAddTagsAction.h"
#import "UARemoveTagsAction.h"
#import "UALandingPageAction.h"
#import "UAirship.h"
#import "UAApplicationMetrics.h"
#import "UACloseWindowAction.h"
#import "UAAddCustomEventAction.h"
#import "UAShareAction.h"

@implementation UAActionRegistry
@dynamic registeredEntries;

SINGLETON_IMPLEMENTATION(UAActionRegistry)

- (instancetype)init {
    self = [super init];
    if (self) {
        self.registeredActionEntries = [[NSMutableDictionary alloc] init];
        self.reservedEntryNames = [NSMutableArray array];

        [self registerDefaultActions];
    }
    return self;
}


-(BOOL)registerAction:(UAAction *)action names:(NSArray *)names {
    return [self registerAction:action names:names predicate:nil];
}

- (BOOL)registerAction:(UAAction *)action name:(NSString *)name {
    return [self registerAction:action name:name predicate:nil];
}

- (BOOL)registerAction:(UAAction *)action
                  name:(NSString *)name
             predicate:(UAActionPredicate)predicate {

    NSArray *names = name ? @[name] : nil;
    return [self registerAction:action names:names predicate:predicate];
}

-(BOOL)registerAction:(UAAction *)action
                names:(NSArray *)names
            predicate:(UAActionPredicate)predicate {

    if (!action) {
        UA_LWARN(@"Unable to register a nil action.");
        return NO;
    }

    if (!names.count) {
        UA_LWARN(@"Unable to register action.  A name must be specified.");
        return NO;
    }

    for (NSString *name in names) {
        if ([self.reservedEntryNames containsObject:name]) {
            UA_LWARN(@"Unable to register entry. %@ is a reserved action.", name);
            return NO;
        }
    }

    UAActionRegistryEntry *entry = [UAActionRegistryEntry entryForAction:action
                                                               predicate:predicate];

    for (NSString *name in names) {
        [self removeName:name];
        [entry.mutableNames addObject:name];
        [self.registeredActionEntries setValue:entry forKey:name];
    }
    
    return YES;
}


- (BOOL)registerReservedAction:(UAAction *)action
                          name:(NSString *)name
                     predicate:(UAActionPredicate)predicate {
    if ([self registerAction:action name:name predicate:predicate]) {
        [self.reservedEntryNames addObject:name];
        return YES;
    }
    return NO;
}

- (BOOL)removeName:(NSString *)name {
    if (!name) {
        return YES;
    }

    if ([self.reservedEntryNames containsObject:name]) {
        UA_LWARN(@"Unable to remove name for action. %@ is a reserved action name.", name);
        return NO;
    }

    UAActionRegistryEntry *entry = [self registryEntryWithName:name];
    if (entry) {
        [entry.mutableNames removeObject:name];
        [self.registeredActionEntries removeObjectForKey:name];
    }

    return YES;
}

- (BOOL)removeEntryWithName:(NSString *)name {
    if (!name) {
        return YES;
    }

    if ([self.reservedEntryNames containsObject:name]) {
        UA_LWARN(@"Unable to remove entry. %@ is a reserved action name.", name);
        return NO;
    }

    UAActionRegistryEntry *entry = [self registryEntryWithName:name];

    for (NSString *entryName in entry.mutableNames) {
        if ([self.reservedEntryNames containsObject:entryName]) {
            UA_LWARN(@"Unable to remove entry. %@ is a reserved action.", name);
            return NO;
        }
    }

    for (NSString *entryName in entry.mutableNames) {
        [self.registeredActionEntries removeObjectForKey:entryName];
    }

    return YES;
}

- (BOOL)addName:(NSString *)name forEntryWithName:(NSString *)entryName {
    if (!name) {
        UA_LWARN(@"Unable to add a nil name for entry.");
        return NO;
    }

    if ([self.reservedEntryNames containsObject:entryName]) {
        UA_LWARN(@"Unable to add name to a reserved entry. %@ is a reserved action name.", entryName);
        return NO;
    }

    if ([self.reservedEntryNames containsObject:name]) {
        UA_LWARN(@"Unable to add name for entry. %@ is a reserved action name.", name);
        return NO;
    }

    UAActionRegistryEntry *entry = [self registryEntryWithName:entryName];
    if (entry && name) {
        [self removeName:name];
        [entry.mutableNames addObject:name];
        [self.registeredActionEntries setValue:entry forKey:name];
        return YES;
    }

    return NO;
}

- (UAActionRegistryEntry *)registryEntryWithName:(NSString *)name {
    if (!name) {
        return nil;
    }

    return [self.registeredActionEntries valueForKey:name];
}

- (NSSet *)registeredEntries {
    NSMutableDictionary *entries = [NSMutableDictionary dictionaryWithDictionary:self.registeredActionEntries];
    [entries removeObjectsForKeys:self.reservedEntryNames];
    return [NSSet setWithArray:[entries allValues]];
}

- (BOOL)addSituationOverride:(UASituation)situation
            forEntryWithName:(NSString *)name action:(UAAction *)action {
    if (!name) {
        return NO;
    }

    // Don't allow situation overrides on reserved actions
    if ([self.reservedEntryNames containsObject:name]) {
        UA_LWARN(@"Unable to override situations. %@ is a reserved action name.", name);
        return NO;
    }

    UAActionRegistryEntry *entry = [self registryEntryWithName:name];
    [entry addSituationOverride:situation withAction:action];

    return (entry != nil);
}

- (BOOL)updatePredicate:(UAActionPredicate)predicate forEntryWithName:(NSString *)name {
    if (!name) {
        return NO;
    }

    if ([self.reservedEntryNames containsObject:name]) {
        UA_LWARN(@"Unable to update predicate. %@ is a reserved action name.", name);
        return NO;
    }

    UAActionRegistryEntry *entry = [self registryEntryWithName:name];
    entry.predicate = predicate;
    return (entry != nil);
}

- (BOOL)updateAction:(UAAction *)action forEntryWithName:(NSString *)name {
    if (!name || !action) {
        return NO;
    }

    if ([self.reservedEntryNames containsObject:name]) {
        UA_LWARN(@"Unable to update action. %@ is a reserved action name.", name);
        return NO;
    }

    UAActionRegistryEntry *entry = [self registryEntryWithName:name];
    entry.action = action;
    return (entry != nil);
}

- (void)registerDefaultActions {
    // Incoming push action
    UAIncomingPushAction *incomingPushAction = [[UAIncomingPushAction alloc] init];
    [self registerReservedAction:incomingPushAction name:kUAIncomingPushActionRegistryName predicate:nil];

    // Incoming RAP action
    UAIncomingRichPushAction *richPushAction = [[UAIncomingRichPushAction alloc] init];
    [self registerReservedAction:richPushAction name:kUAIncomingRichPushActionRegistryName predicate:nil];

    // Close window action
    UACloseWindowAction *closeWindowAction = [[UACloseWindowAction alloc] init];
    [self registerReservedAction:closeWindowAction name:kUACloseWindowActionRegistryName predicate:nil];

    // Open external URL predicate
    UAActionPredicate urlPredicate = ^(UAActionArguments *args) {
        return (BOOL)(args.situation != UASituationForegroundPush);
    };

    // Open external URL action
    UAOpenExternalURLAction *urlAction = [[UAOpenExternalURLAction alloc] init];
    [self registerAction:urlAction
                    names:@[kUAOpenExternalURLActionDefaultRegistryName, kUAOpenExternalURLActionDefaultRegistryAlias]
               predicate:urlPredicate];


    UAAddTagsAction *addTagsAction = [[UAAddTagsAction alloc] init];
    [self registerAction:addTagsAction
                    names:@[kUAAddTagsActionDefaultRegistryName, kUAAddTagsActionDefaultRegistryAlias]];


    UARemoveTagsAction *removeTagsAction = [[UARemoveTagsAction alloc] init];
    [self registerAction:removeTagsAction
                    names:@[kUARemoveTagsActionDefaultRegistryName, kUARemoveTagsActionDefaultRegistryAlias]];

    UALandingPageAction *landingPageAction = [[UALandingPageAction alloc] init];
    [self registerAction:landingPageAction
                   names:@[kUALandingPageActionDefaultRegistryName, kUALandingPageActionDefaultRegistryAlias]
               predicate:^(UAActionArguments *args) {
                   if (UASituationBackgroundPush == args.situation) {
                       UAApplicationMetrics *metrics = [UAirship shared].applicationMetrics;
                       NSTimeInterval timeSinceLastOpen = [[NSDate date] timeIntervalSinceDate:metrics.lastApplicationOpenDate];
                       return (BOOL)(timeSinceLastOpen <= [kUALandingPageActionLastOpenTimeLimitInSeconds doubleValue]);
                   }
                   return (BOOL)(args.situation != UASituationForegroundPush);
    }];

    // Register external URL action under the deep link action name/alias
    UAOpenExternalURLAction *deepLinkAction = [[UAOpenExternalURLAction alloc] init];
    [self registerAction:deepLinkAction
                   names:@[kUADeepLinkActionDefaultRegistryName, kUADeepLinkActionDefaultRegistryAlias]
               predicate:urlPredicate];

    UAAddCustomEventAction *addCustomEventAction = [[UAAddCustomEventAction alloc] init];
    [self registerAction:addCustomEventAction
                    name:kUAAddCustomEventActionDefaultRegistryName
               predicate:^BOOL(UAActionArguments *args) {
                   return args.situation == UASituationManualInvocation || args.situation == UASituationWebViewInvocation;
    }];

    // Share action
    UAShareAction *shareAction = [[UAShareAction alloc] init];
    [self registerAction:shareAction names:@[kUAShareActionDefaultRegistryName, kUAShareActionDefaultRegistryAlias] predicate:^(UAActionArguments *args) {
        return (BOOL)(args.situation != UASituationForegroundPush);
    }];
}

@end
