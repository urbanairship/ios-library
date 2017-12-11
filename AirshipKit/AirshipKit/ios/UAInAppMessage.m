/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessage+Internal.h"

@implementation UAInAppMessageBuilder

NSString * const UAInAppMessageErrorDomain = @"com.urbanairship.in_app_message";

@end

@implementation UAInAppMessage

// Keys via IAM v2 spec
NSString *const UAInAppMessageIDKey = @"message_id";
NSString *const UAInAppMessageDisplayTypeKey = @"display_type";
NSString *const UAInAppMessageDisplayContentKey = @"display";
NSString *const UAInAppMessageExtrasKey = @"extras";

NSString *const UAInAppMessageDisplayTypeBanner = @"banner";
NSString *const UAInAppMessageDisplayTypeFullScreen = @"full_screen";
NSString *const UAInAppMessageDisplayTypeModal = @"modal";
NSString *const UAInAppMessageDisplayTypeHTML = @"html";
NSString *const UAInAppMessageDisplayTypeCustom = @"custom";

+ (instancetype)message {
    return [[self alloc] init];
}

+ (instancetype)messageWithJSON:(NSDictionary *)json {
    UAInAppMessageBuilder *builder = [[UAInAppMessageBuilder alloc] init];

    id (^typeCheck)(id, Class) = ^id(id value, Class class) {
        return [value isKindOfClass:class] ? value : nil;
    };

    builder.json = json;

    // top-level keys
    NSString *messageID = typeCheck(json[UAInAppMessageIDKey], [NSString class]);
    NSString *displayType =  typeCheck(json[UAInAppMessageDisplayTypeKey], [NSString class]);
    NSDictionary *extras = typeCheck(json[UAInAppMessageExtrasKey], [NSDictionary class]);
    // TODO Update this to actual object
    id displayContent = typeCheck(json[UAInAppMessageDisplayContentKey], [NSObject class]);

    builder.identifier = messageID;
    builder.displayType = displayType;
    builder.extras = extras;
    builder.displayContent = displayContent;

    return [[UAInAppMessage alloc] initWithBuilder:builder];
}

+ (instancetype)messageWithBuilderBlock:(void(^)(UAInAppMessageBuilder *builder))builderBlock {
    UAInAppMessageBuilder *builder = [[UAInAppMessageBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessage alloc] initWithBuilder:builder];
}

- (instancetype)initWithBuilder:(UAInAppMessageBuilder *)builder {
    self = [super init];
    if (self) {
        self.json = builder.json;
        self.identifier = builder.identifier;
        self.displayType = builder.displayType;
        self.displayContent = builder.displayContent;
        self.extras = builder.extras;
    }

    return self;
}

- (BOOL)isEqualToInAppMessage:(UAInAppMessage *)message {
    if (![self.identifier isEqualToString:message.identifier]) {
        return NO;
    }

    if (self.displayType != message.displayType) {
        return NO;
    }

    // TODO update to check actual object
    if (self.displayContent != message.displayContent) {
        return NO;
    }

    if (![self.extras isEqualToDictionary:message.extras]) {
        return NO;
    }

    return YES;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessage class]]) {
        return NO;
    }

    return [self isEqualToInAppMessage:(UAInAppMessage *)object];
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.identifier hash];
    result = 31 * result + [self.displayType hash];
    result = 31 * result + [self.displayContent hash];
    result = 31 * result + [self.extras hash];

    return result;
}

//TODO implement description method

@end
