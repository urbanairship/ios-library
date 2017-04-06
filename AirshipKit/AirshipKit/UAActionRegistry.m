/* Copyright 2017 Urban Airship and Contributors */

#import "UAActionRegistry+Internal.h"
#import "UAActionRegistryEntry+Internal.h"
#import "UAOpenExternalURLAction.h"
#import "UAAddTagsAction.h"
#import "UARemoveTagsAction.h"
#import "UALandingPageAction.h"
#import "UAirship.h"
#import "UAApplicationMetrics.h"
#import "UAAddCustomEventAction.h"
#import "UAShareAction.h"
#import "UADisplayInboxAction.h"
#import "UAPasteboardAction.h"
#import "UAOverlayInboxMessageAction.h"
#import "UACancelSchedulesAction.h"
#import "UAScheduleAction.h"
#import "UAFetchDeviceInfoAction.h"
#import "UAChannelCaptureAction.h"
#import "UAEnableFeatureAction.h"

@implementation UAActionRegistry
@dynamic registeredEntries;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.registeredActionEntries = [[NSMutableDictionary alloc] init];
        self.reservedEntryNames = [NSMutableArray array];
    }
    return self;
}


+ (instancetype)defaultRegistry {
    UAActionRegistry *registry = [[UAActionRegistry alloc] init];
    [registry registerDefaultActions];
    return registry;
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

    if (!name) {
        return NO;
    }

    return [self registerAction:action names:@[name] predicate:predicate];
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
            forEntryWithName:(NSString *)name
                      action:(UAAction *)action {
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
    // Open external URL predicate
    UAActionPredicate urlPredicate = ^(UAActionArguments *args) {
        return (BOOL)(args.situation != UASituationForegroundPush);
    };

    // Tags predicate
    UAActionPredicate tagsPredicate = ^(UAActionArguments *args) {
        BOOL foregroundPresentation = args.metadata[UAActionMetadataForegroundPresentationKey] != nil;
        return (BOOL)!foregroundPresentation;
    };

    // Custom event predicate
    UAActionPredicate customEventsPredicate = ^(UAActionArguments *args) {
        BOOL foregroundPresentation = args.metadata[UAActionMetadataForegroundPresentationKey] != nil;
        return (BOOL)!foregroundPresentation;
    };

    // Open external URL action
    UAOpenExternalURLAction *urlAction = [[UAOpenExternalURLAction alloc] init];
    [self registerAction:urlAction
                   names:@[kUAOpenExternalURLActionDefaultRegistryName, kUAOpenExternalURLActionDefaultRegistryAlias]
               predicate:urlPredicate];


    UAAddTagsAction *addTagsAction = [[UAAddTagsAction alloc] init];
    [self registerAction:addTagsAction
                   names:@[kUAAddTagsActionDefaultRegistryName, kUAAddTagsActionDefaultRegistryAlias]
               predicate:tagsPredicate];


    UARemoveTagsAction *removeTagsAction = [[UARemoveTagsAction alloc] init];
    [self registerAction:removeTagsAction
                   names:@[kUARemoveTagsActionDefaultRegistryName, kUARemoveTagsActionDefaultRegistryAlias]
               predicate:tagsPredicate];

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

    // Custom event action
    UAAddCustomEventAction *addCustomEventAction = [[UAAddCustomEventAction alloc] init];
    [self registerAction:addCustomEventAction
                    name:kUAAddCustomEventActionDefaultRegistryName
               predicate:customEventsPredicate];

    // Share action
    UAShareAction *shareAction = [[UAShareAction alloc] init];
    [self registerAction:shareAction names:@[kUAShareActionDefaultRegistryName, kUAShareActionDefaultRegistryAlias] predicate:^(UAActionArguments *args) {
        return (BOOL)(args.situation != UASituationForegroundPush);
    }];

    // Display inbox action
    UADisplayInboxAction *displayInboxAction = [[UADisplayInboxAction alloc] init];
    [self registerAction:displayInboxAction
                   names:@[kUADisplayInboxActionDefaultRegistryAlias, kUADisplayInboxActionDefaultRegistryName]];

    // Pasteboard action
    [self registerAction:[[UAPasteboardAction alloc] init]
                   names:@[kUAPasteboardActionDefaultRegistryAlias, kUAPasteboardActionDefaultRegistryName]];


    // Overlay inbox message action
    [self registerAction:[[UAOverlayInboxMessageAction alloc] init]
                   names:@[kUAOverlayInboxMessageActionDefaultRegistryAlias, kUAOverlayInboxMessageActionDefaultRegistryName]
               predicate:^(UAActionArguments *args) {
                   return (BOOL)(args.situation != UASituationForegroundPush);
               }];

    // Wallet action
    [self registerAction:[[UAOpenExternalURLAction alloc] init]
                   names:@[kUAWalletActionDefaultRegistryAlias, kUAWalletActionDefaultRegistryName]];

    // Cancel schedules action
    [self registerAction:[[UACancelSchedulesAction alloc] init]
                   names:@[kUACancelSchedulesActionDefaultRegistryName, kUACancelSchedulesActionDefaultRegistryAlias]];

    // Schedule action
    [self registerAction:[[UAScheduleAction alloc] init]
                   names:@[kUAScheduleActionDefaultRegistryName, kUAScheduleActionDefaultRegistryAlias]];
    
    // Fetch device info action
    UAFetchDeviceInfoAction *fetchDeviceInfoAction = [[UAFetchDeviceInfoAction alloc] init];
    [self registerAction:fetchDeviceInfoAction
                   names:@[kUAFetchDeviceInfoActionDefaultRegistryName, kUAFetchDeviceInfoActionDefaultRegistryAlias]
               predicate:^BOOL(UAActionArguments *args) {
                   return args.situation == UASituationManualInvocation || args.situation == UASituationWebViewInvocation;
               }];
    
    // Channel capture action
    UAChannelCaptureAction *channelCaptureAction = [[UAChannelCaptureAction alloc] init];
    [self registerAction:channelCaptureAction
                    names:@[kUAChannelCaptureActionDefaultRegistryName, kUAChannelCaptureActionDefaultRegistryAlias]];

    // Enable feature action
    UAEnableFeatureAction *enableFeatureAction = [[UAEnableFeatureAction alloc] init];
    [self registerAction:enableFeatureAction
                   names:@[kUAEnableFeatureActionDefaultRegistryName, kUAEnableFeatureActionDefaultRegistryAlias]
               predicate:^BOOL(UAActionArguments *args) {
                   BOOL foregroundPresentation = args.metadata[UAActionMetadataForegroundPresentationKey] != nil;
                   return (BOOL)!foregroundPresentation;
               }];
}

@end
