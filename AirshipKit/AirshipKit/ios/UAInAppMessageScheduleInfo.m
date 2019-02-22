/* Copyright Urban Airship and Contributors */

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

- (BOOL)applyFromJson:(id)json source:(UAInAppMessageSource)source error:(NSError * _Nullable *)error {
    if (![super applyFromJson:json error:error]) {
        return NO;
    }

    // Message
    id messagePayload = json[UAScheduleInfoInAppMessageKey];
    if (messagePayload) {
        if (![messagePayload isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message payload must be a dictionary. Invalid value: %@", messagePayload];
                *error =  [NSError errorWithDomain:UAScheduleInfoErrorDomain
                                              code:UAScheduleInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        self.message = [UAInAppMessage messageWithJSON:messagePayload defaultSource:source error:error];
        if (!self.message) {
            return NO;
        }
    }

    return YES;
}

@end

@interface UAInAppMessageScheduleInfo()
@property(nonatomic, strong) UAInAppMessage *message;
@end

@implementation UAInAppMessageScheduleInfo
@synthesize message = _message;

- (UAInAppMessage *)message {
    if (!_message) {
        _message = [UAInAppMessage messageWithJSON:[NSJSONSerialization objectWithString:self.data] error:nil];
    }
    return _message;
}

+ (nullable instancetype)scheduleInfoWithBuilderBlock:(void(^)(UAInAppMessageScheduleInfoBuilder *builder))builderBlock {
    UAInAppMessageScheduleInfoBuilder *builder = [[UAInAppMessageScheduleInfoBuilder alloc] init];
    builder.limit = 1;

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[self alloc] initWithBuilder:builder];
}

+ (nullable instancetype)scheduleInfoWithJSON:(id)json source:(UAInAppMessageSource)source error:(NSError **)error {
    UAInAppMessageScheduleInfoBuilder *builder = [[UAInAppMessageScheduleInfoBuilder alloc] init];
    if (![builder applyFromJson:json source:source error:error]) {
        return nil;
    }

    return [[self alloc] initWithBuilder:builder];
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
