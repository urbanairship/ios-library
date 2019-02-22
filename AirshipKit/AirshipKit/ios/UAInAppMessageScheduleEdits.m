/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageScheduleEdits.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageScheduleInfo.h"

#import "UAScheduleEdits+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"

@implementation UAInAppMessageScheduleEditsBuilder

- (NSString *)data {
    if (self.message) {
        return [NSJSONSerialization stringWithObject:[self.message toJSON]];
    } else {
        return nil;
    }
}

- (BOOL)applyFromJson:(id)json error:(NSError * _Nullable *)error {
    if (![super applyFromJson:json error:error]) {
        return NO;
    }

    // Message
    id messagePayload = json[UAScheduleInfoInAppMessageKey];
    if (messagePayload) {
        if (![messagePayload isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message payload must be a dictionary. Invalid value: %@", messagePayload];
                *error =  [NSError errorWithDomain:UAScheduleEditsErrorDomain
                                              code:UAScheduleEditsErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        self.message = [UAInAppMessage messageWithJSON:messagePayload error:error];
        if (!self.message) {
            return NO;
        }
    }

    return YES;
}

@end

@implementation UAInAppMessageScheduleEdits

- (UAInAppMessage *)message {
    return [UAInAppMessage messageWithJSON:[NSJSONSerialization objectWithString:self.data] error:nil];
}

+ (instancetype)editsWithBuilderBlock:(void (^)(UAInAppMessageScheduleEditsBuilder *))builderBlock {
    UAInAppMessageScheduleEditsBuilder *builder = [[UAInAppMessageScheduleEditsBuilder alloc] init];
    if (builderBlock) {
        builderBlock(builder);
    }

    return [[self alloc] initWithBuilder:builder];
}

+ (instancetype)editsWithJSON:(id)json error:(NSError **)error {
    UAInAppMessageScheduleEditsBuilder *builder = [[UAInAppMessageScheduleEditsBuilder alloc] init];
    if (![builder applyFromJson:json error:error]) {
        return nil;
    }

    return [[self alloc] initWithBuilder:builder];
}

@end

