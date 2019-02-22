/* Copyright Urban Airship and Contributors */

#import "UAActionScheduleInfo.h"
#import "UAScheduleEdits+Internal.h"
#import "UAActionScheduleEdits.h"
#import "NSJSONSerialization+UAAdditions.h"

@implementation UAActionScheduleEditsBuilder

- (NSString *)data {
    if (self.actions) {
        return [NSJSONSerialization stringWithObject:self.actions];
    } else {
        return nil;
    }
}

@end


@implementation UAActionScheduleEdits

- (NSDictionary *)actions {
    return [NSJSONSerialization objectWithString:self.data];
}

+ (instancetype)editsWithBuilderBlock:(void (^)(UAActionScheduleEditsBuilder *))builderBlock {
    UAActionScheduleEditsBuilder *builder = [[UAActionScheduleEditsBuilder alloc] init];
    if (builderBlock) {
        builderBlock(builder);
    }

    return [[self alloc] initWithBuilder:builder];
}

@end

