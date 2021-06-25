/* Copyright Airship and Contributors */

#import "UAActionRegistry+Internal.h"
#import "UAActionRegistryEntry+Internal.h"
#import "UAirship.h"
#import "UAActionPredicateProtocol.h"


#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

NSString *const UAActionRegistryActionKey = @"action";
NSString *const UAActionRegistryNamesKey = @"names";
NSString *const UAActionRegistryPredicateClassKey = @"predicate";

@implementation UAActionRegistry
@dynamic registeredEntries;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.registeredActionEntries = [[NSMutableDictionary alloc] init];
    }
    return self;
}

+ (instancetype)defaultRegistry {
    UAActionRegistry *registry = [[UAActionRegistry alloc] init];
    [registry registerDefaultActions];
    return registry;
}

- (BOOL)registerAction:(UAAction *)action names:(NSArray *)names {
    return [self registerAction:action names:names predicate:nil];
}

- (BOOL)registerAction:(UAAction *)action name:(NSString *)name {
    return [self registerAction:action name:name predicate:nil];
}

- (BOOL)registerActionClass:(Class)actionClass names:(NSArray *)names {
    return [self registerActionClass:actionClass names:names predicate:nil];
}

- (BOOL)registerActionClass:(Class)actionClass name:(NSString *)name {
    return [self registerActionClass:actionClass name:name predicate:nil];
}

- (BOOL)registerAction:(UAAction *)action
                  name:(NSString *)name
             predicate:(UAActionPredicate)predicate {

    if (!name) {
        return NO;
    }

    return [self registerAction:action names:@[name] predicate:predicate];
}

- (BOOL)registerActionClass:(Class)actionClass
                       name:(NSString *)name
                  predicate:(UAActionPredicate)predicate {
    if (!name) {
        return NO;
    }

    return [self registerActionClass:actionClass names:@[name] predicate:predicate];
}

- (BOOL)registerActionClass:(Class)actionClass
                      names:(NSArray *)names
                  predicate:(UAActionPredicate)predicate {

    if (![actionClass isSubclassOfClass:[UAAction class]]) {
        UA_LERR(@"Unable to register an action class that isn't a subclass of UAAction.");
        return NO;
    }

    if (!actionClass) {
        UA_LERR(@"Unable to register a nil action class.");
        return NO;
    }

    UAActionRegistryEntry *entry = [UAActionRegistryEntry entryForActionClass:actionClass
                                                                    predicate:predicate];

    return [self registerEntry:entry names:names];
}

- (BOOL)registerAction:(UAAction *)action
                 names:(NSArray *)names
             predicate:(UAActionPredicate)predicate {

    if (!action) {
        UA_LERR(@"Unable to register a nil action.");
        return NO;
    }

    UAActionRegistryEntry *entry = [UAActionRegistryEntry entryForAction:action
                                                               predicate:predicate];

    return [self registerEntry:entry names:names];
}

- (BOOL)registerEntry:(UAActionRegistryEntry *)entry
                names:(NSArray *)names {

    if (!names.count) {
        UA_LERR(@"Unable to register action class. A name must be specified.");
        return NO;
    }

    for (NSString *name in names) {
        [self removeName:name];
        [entry.mutableNames addObject:name];
        [self.registeredActionEntries setValue:entry forKey:name];
    }

    return YES;
}

- (BOOL)removeName:(NSString *)name {
    if (!name) {
        return YES;
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

    UAActionRegistryEntry *entry = [self registryEntryWithName:name];

    for (NSString *entryName in entry.mutableNames) {
        [self.registeredActionEntries removeObjectForKey:entryName];
    }

    return YES;
}

- (BOOL)addName:(NSString *)name forEntryWithName:(NSString *)entryName {
    if (!name) {
        UA_LERR(@"Unable to add a nil name for entry.");
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
    return [NSSet setWithArray:[entries allValues]];
}

- (BOOL)addSituationOverride:(UASituation)situation
            forEntryWithName:(NSString *)name
                      action:(UAAction *)action {
    if (!name) {
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

    UAActionRegistryEntry *entry = [self registryEntryWithName:name];
    entry.predicate = predicate;
    return (entry != nil);
}

- (BOOL)updateAction:(UAAction *)action forEntryWithName:(NSString *)name {
    if (!name || !action) {
        return NO;
    }

    UAActionRegistryEntry *entry = [self registryEntryWithName:name];
    entry.action = action;
    return (entry != nil);
}

- (BOOL)updateActionClass:(Class)actionClass forEntryWithName:(NSString *)name {
    if (!name || !actionClass) {
        return NO;
    }

    UAActionRegistryEntry *entry = [self registryEntryWithName:name];
    entry.actionClass = actionClass;
    return (entry != nil);
}

- (void)registerActionsFromFile:(NSString *)path {
    NSArray *actions = [NSArray arrayWithContentsOfFile:path];

    if (!actions) {
        return;
    }

    for (NSDictionary *actionEntry in actions) {
        NSArray *names = actionEntry[UAActionRegistryNamesKey];
        NSString *actionClassName = actionEntry[UAActionRegistryActionKey];
        NSString *predicateClassName = actionEntry[UAActionRegistryPredicateClassKey];
        BOOL (^predicateBlock)(UAActionArguments *) = nil;

        if (!names.count) {
            UA_LERR(@"Missing action names for entry %@", actionEntry);
            continue;
        }

        if (!actionClassName.length) {
            UA_LERR(@"Missing action class name for entry %@", actionEntry);
            continue;
        }

        Class actionClass = NSClassFromString(actionClassName);
        if (![actionClass isSubclassOfClass:[UAAction class]]) {
            UA_LERR(@"Unable to register an action class that isn't a subclass of UAAction. Invalid action class for entry: %@", actionEntry);
            continue;
        }

        if (predicateClassName) {
            Class predicateClass = NSClassFromString(predicateClassName);
            if (![predicateClass conformsToProtocol:@protocol(UAActionPredicateProtocol)]) {
                UA_LERR(@"Unable to register protocol class that does not conform to UAActionPredicateProtocol. Invalid predicate for entry: %@", actionEntry);
                continue;
            }

            id<UAActionPredicateProtocol> predicate = [predicateClass predicate];
            predicateBlock = ^BOOL(UAActionArguments *args) {
                return [predicate applyActionArguments:args];
            };
        }

        [self registerActionClass:actionClass
                            names:names
                        predicate:predicateBlock];
    }
}

- (void)registerDefaultActions {
#if TARGET_OS_TV
    NSString *path = [[UAirshipCoreResources bundle] pathForResource:@"UADefaultActionsTVOS" ofType:@"plist"];
#else
    NSString *path = [[UAirshipCoreResources bundle] pathForResource:@"UADefaultActions" ofType:@"plist"];
#endif

    if (path) {
        [self registerActionsFromFile:path];
    }
}

@end
