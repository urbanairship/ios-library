/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageButtonInfo.h"
#import "UAGlobal.h"

NS_ASSUME_NONNULL_BEGIN
NSString *const UAInAppMessageButtonInfoDomain = @"com.urbanairship.in_app_message_button_info";

NSString *const UAInAppMessageButtonInfoBehaviorCancel = @"cancel";
NSString *const UAInAppMessageButtonInfoBehaviorDismiss = @"dismiss";

// JSON Keys
NSString *const UAInAppMessageButtonInfoLabelKey = @"label";
NSString *const UAInAppMessageButtonInfoIdentifierKey = @"id";
NSString *const UAInAppMessageButtonInfoBehaviorKey = @"behavior";
NSString *const UAInAppMessageButtonInfoBorderRadiusKey = @"border_radius";
NSString *const UAInAppMessageButtonInfoBackgroundColorKey = @"background_color";
NSString *const UAInAppMessageButtonInfoBorderColorKey = @"border_color";
NSString *const UAInAppMessageButtonInfoActionsKey = @"actions";

@interface UAInAppMessageButtonInfo ()
@property(nonatomic, strong) UAInAppMessageTextInfo *label;
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *behavior;
@property(nonatomic, copy) NSString *backgroundColor;
@property(nonatomic, copy) NSString *borderColor;
@property(nonatomic, assign) NSUInteger borderRadius;
@property(nonatomic, copy, nullable) NSDictionary *actions;
@end

@implementation UAInAppMessageButtonInfoBuilder
@end

@implementation UAInAppMessageButtonInfo

- (instancetype)initWithBuilder:(UAInAppMessageButtonInfoBuilder *)builder {
    self = [super self];

    if (![UAInAppMessageButtonInfo validateBuilder:builder]) {
        UA_LDEBUG(@"UAInAppMessageButtonInfo instance could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }

    if (self) {
        self.label = builder.label;
        self.identifier = builder.identifier;
        self.behavior = builder.behavior ?: UAInAppMessageButtonInfoBehaviorDismiss;
        self.backgroundColor = builder.backgroundColor ?: @"#FF000000";
        self.borderRadius = builder.borderRadius;
        self.borderColor = builder.borderColor ?: @"#FF000000";
        self.actions = builder.actions;
    }

    return self;
}

+ (nullable instancetype)buttonInfoWithBuilderBlock:(void(^)(UAInAppMessageButtonInfoBuilder *builder))builderBlock {
    UAInAppMessageButtonInfoBuilder *builder = [[UAInAppMessageButtonInfoBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageButtonInfo alloc] initWithBuilder:builder];
}

+ (nullable instancetype)buttonInfoWithJSON:(id)json error:(NSError * _Nullable *)error {

    UAInAppMessageTextInfo *label;
    id labelDict = json[UAInAppMessageButtonInfoLabelKey];
    if (labelDict && ![labelDict isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message button label must be an dictionary. Invalid value: %@", labelDict];
            *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                          code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    label = [UAInAppMessageTextInfo textInfoWithJSON:labelDict error:error];

    NSString *identifier;
    id identifierText = json[UAInAppMessageButtonInfoIdentifierKey];
    if (identifierText && ![identifierText isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message button identifier must be a string. Invalid value: %@", identifierText];
            *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                          code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }
    identifier = identifierText;

    NSString *behavior;
    id behaviorContents = json[UAInAppMessageButtonInfoBehaviorKey];
    if (behaviorContents) {
        if (![behaviorContents isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Behavior must be a string."];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }

       behavior = [behaviorContents lowercaseString];

        if ([UAInAppMessageButtonInfoBehaviorCancel isEqualToString:behavior]) {
            behavior = UAInAppMessageButtonInfoBehaviorCancel;
        } else if ([UAInAppMessageButtonInfoBehaviorDismiss isEqualToString:behavior]) {
            behavior = UAInAppMessageButtonInfoBehaviorDismiss;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message button behavior: %@", behavior];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }
    }

    NSString *backgroundColor;
    id backgroundColorHex = json[UAInAppMessageButtonInfoBackgroundColorKey];
    if (backgroundColorHex && ![backgroundColorHex isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message button background color must be a hex string. Invalid value: %@", backgroundColorHex];
            *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                          code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }
    backgroundColor = backgroundColorHex;

    NSString *borderColor;
    id borderColorHex = json[UAInAppMessageButtonInfoBorderColorKey];
    if (borderColorHex && ![borderColorHex isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message button border color must be a hex string. Invalid value: %@", borderColorHex];
            *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                          code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }
    borderColor = borderColorHex;

    id borderRadius = json[UAInAppMessageButtonInfoBorderRadiusKey];
    if (borderRadius && ![borderRadius isKindOfClass:[NSNumber class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Button border radius must be a number. Invalid value: %@", borderRadius];
            *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                          code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    // Actions
    id actions = json[UAInAppMessageButtonInfoActionsKey];
    if (actions && ![actions isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Button actions payload must be a dictionary. Invalid value: %@", actions];
            *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                          code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    return [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder * _Nonnull builder) {
        builder.label = label;
        builder.identifier = identifier;
        builder.behavior = behavior;
        builder.backgroundColor = backgroundColor;
        builder.borderColor = borderColor;
        builder.borderRadius = [borderRadius unsignedIntegerValue];
        builder.actions = actions;
    }];
}

+ (NSDictionary *)JSONWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    if (!buttonInfo) {
        return nil;
    }

    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    json[UAInAppMessageButtonInfoLabelKey] = [UAInAppMessageTextInfo JSONWithTextInfo:buttonInfo.label];
    json[UAInAppMessageButtonInfoIdentifierKey] = buttonInfo.identifier;
    json[UAInAppMessageButtonInfoBorderRadiusKey] = [NSNumber numberWithInteger:buttonInfo.borderRadius];
    json[UAInAppMessageButtonInfoBehaviorKey] = buttonInfo.behavior;
    json[UAInAppMessageButtonInfoBorderColorKey] = buttonInfo.borderColor;
    json[UAInAppMessageButtonInfoBackgroundColorKey] = buttonInfo.backgroundColor;
    json[UAInAppMessageButtonInfoActionsKey] = buttonInfo.actions;

    return [NSDictionary dictionaryWithDictionary:json];
}

#pragma mark - Validation

// Validates builder contents for the banner type
+ (BOOL)validateBuilder:(UAInAppMessageButtonInfoBuilder *)builder {
    if (!builder.label) {
        UA_LDEBUG(@"In-app button infos require a label");
        return NO;
    }

    return YES;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessageButtonInfo class]]) {
        return NO;
    }

    return [self isEqualToInAppMessageButtonInfo:(UAInAppMessageButtonInfo *)object];
}

- (BOOL)isEqualToInAppMessageButtonInfo:(UAInAppMessageButtonInfo *)info {

    if (self.label != info.label && ![self.label isEqual:info.label]) {
        return NO;
    }

    if (self.identifier != info.identifier && ![self.identifier isEqualToString:info.identifier]) {
        return NO;
    }

    if (self.behavior != info.behavior && ![self.behavior isEqualToString:info.behavior]) {
        return NO;
    }

    if (self.backgroundColor != info.backgroundColor && ![self.backgroundColor isEqualToString:info.backgroundColor]) {
        return NO;
    }

    if (self.borderColor != info.borderColor && ![self.borderColor isEqualToString:info.borderColor]) {
        return NO;
    }

    if (self.actions != info.actions && ![self.actions isEqualToDictionary:info.actions]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.label hash];
    result = 31 * result + [self.identifier hash];
    result = 31 * result + [self.behavior hash];
    result = 31 * result + [self.backgroundColor hash];
    result = 31 * result + [self.borderColor hash];
    result = 31 * result + [self.actions hash];

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAInAppMessageButtonInfo: %@", self.identifier ?: self.label];
}

@end

NS_ASSUME_NONNULL_END

