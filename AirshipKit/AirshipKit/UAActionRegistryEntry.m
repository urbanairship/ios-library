/* Copyright 2017 Urban Airship and Contributors */

#import "UAActionRegistryEntry+Internal.h"

@interface UAActionRegistryEntry()
@property (nonatomic, strong) NSMutableDictionary *situationOverrides;
@end

@implementation UAActionRegistryEntry
@dynamic names;

- (instancetype)initWithAction:(UAAction *)action predicate:(UAActionPredicate)predicate {
    self = [super init];
    if (self) {
        self.action = action;
        self.predicate = predicate;
        self.mutableNames = [NSMutableArray array];
        self.situationOverrides = [NSMutableDictionary dictionary];
    }

    return self;
}

- (UAAction *)actionForSituation:(UASituation)situation {
    return [self.situationOverrides objectForKey:[NSNumber numberWithInt:situation]] ?: self.action;
}

- (void)addSituationOverride:(UASituation)situation withAction:(UAAction *)action {
    if (action) {
        [self.situationOverrides setObject:action forKey:@(situation)];
    } else {
        [self.situationOverrides removeObjectForKey:@(situation)];
    }
}

+ (instancetype)entryForAction:(UAAction *)action predicate:(UAActionPredicate)predicate {
    return [[self alloc] initWithAction:action predicate:predicate];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAActionRegistryEntry names: %@, predicate: %@, action: %@",
            self.names, self.predicate, self.action];
}

- (NSArray *)names {
    return [NSArray arrayWithArray:self.mutableNames];
}

@end
