/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageScheduleInfo.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAScheduleInfo+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"
#import "UAInAppMessageFullScreenDisplayContent.h"
#import "UAInAppMessageAudience.h"

NSString *const UAScheduleInfoInAppMessageKey = @"message";

@implementation UAInAppMessageScheduleInfoBuilder

@dynamic group;

- (NSString *)group {
    return self.message.identifier;
}

- (NSString *)data {
    if (self.message) {
        return [NSJSONSerialization stringWithObject:[self.message toJSON]];
    } else {
        return nil;
    }
}
@end

@implementation UAInAppMessageScheduleInfo

- (UAInAppMessage *)message {
    return [UAInAppMessage messageWithJSON:[NSJSONSerialization objectWithString:self.data] error:nil];
}

+ (instancetype)inAppMessageScheduleInfoWithBuilderBlock:(void(^)(UAInAppMessageScheduleInfoBuilder *builder))builderBlock {
    UAInAppMessageScheduleInfoBuilder *builder = [[UAInAppMessageScheduleInfoBuilder alloc] init];
    builder.limit = 1;

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageScheduleInfo alloc] initWithBuilder:builder];
}

+ (instancetype)inAppMessageScheduleInfoWithJSON:(id)json error:(NSError **)error {
    UAInAppMessageScheduleInfoBuilder *builder = [[UAInAppMessageScheduleInfoBuilder alloc] init];
    if (![builder applyFromJson:json error:error]) {
        return nil;
    }

    // message ID
    id messagePayload = json[UAScheduleInfoInAppMessageKey];
    if (messagePayload) {
        if (![messagePayload isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message payload must be a dictionary. Invalid value: %@", messagePayload];
                *error =  [NSError errorWithDomain:UAScheduleInfoErrorDomain
                                              code:UAScheduleInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        
        // message with JSON expects displayType to be NSString
        builder.message = [UAInAppMessage messageWithJSON:messagePayload error:error];
        if (!builder.message) {
            return nil;
        }
    }
    
    return [[UAInAppMessageScheduleInfo alloc] initWithBuilder:builder];
}

+ (NSString *)parseMessageID:(id)json {
    id messagePayload = json[UAScheduleInfoInAppMessageKey];
    if (!messagePayload) {
        return nil;
    }
    
    return messagePayload[UAInAppMessageIDKey];
}

- (BOOL)isValid {
    if (![super isValid]) {
        return NO;
    }

    if (!self.message) {
        return NO;
    }

    return YES;
}

@end
