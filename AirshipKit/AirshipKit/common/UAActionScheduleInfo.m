/* Copyright Urban Airship and Contributors */

#import "UAActionScheduleInfo.h"
#import "UAScheduleInfo+Internal.h"
#import "UAUtils+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"


NSString *const UAActionScheduleInfoActionsKey = @"actions";

@implementation UAActionScheduleInfoBuilder

@dynamic group;

- (NSString *)data {
    if (self.actions) {
        return [NSJSONSerialization stringWithObject:self.actions];
    } else {
        return nil;
    }
}

- (BOOL)applyFromJson:(id)json error:(NSError * _Nullable *)error {
    if (![super applyFromJson:json error:error]) {
        return NO;
    }

    // Actions
    id actions = json[UAActionScheduleInfoActionsKey];
    if (![actions isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Actions payload must be a dictionary. Invalid value: %@", actions];
            *error =  [NSError errorWithDomain:UAScheduleInfoErrorDomain
                                          code:UAScheduleInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    self.actions = actions;
    return YES;
}


@end


@implementation UAActionScheduleInfo

@dynamic group;

- (BOOL)isValid {
    if (![super isValid]) {
        return NO;
    }

    if (!self.actions.count) {
        return NO;
    }
    return YES;
}

- (NSDictionary *)actions {
    return [NSJSONSerialization objectWithString:self.data];
}

+ (instancetype)scheduleInfoWithBuilderBlock:(void (^)(UAActionScheduleInfoBuilder *))builderBlock {
    UAActionScheduleInfoBuilder *builder = [[UAActionScheduleInfoBuilder alloc] init];
    builder.limit = 1;

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[self alloc] initWithBuilder:builder];
}

+ (instancetype)scheduleInfoWithJSON:(id)json error:(NSError **)error {
    UAActionScheduleInfoBuilder *builder = [[UAActionScheduleInfoBuilder alloc] init];
    if (![builder applyFromJson:json error:error]) {
        return nil;
    }

    return [[self alloc] initWithBuilder:builder];
}

@end
