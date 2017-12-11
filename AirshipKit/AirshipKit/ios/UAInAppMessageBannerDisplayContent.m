/* Copyright 2017 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageMediaInfo.h"
#import "UAInAppMessageDisplayContent.h"

// JSON keys
NSString *const UAInAppMessageBannerActionsKey = @"actions";
NSString *const UAInAppMessageBannerDisplayContentDomain = @"com.urbanairship.banner_display_content";
NSString *const UAInAppMessageBannerPlacementTop = @"top";
NSString *const UAInAppMessageBannerPlacementBottom = @"bottom";
NSString *const UAInAppMessageBannerContentLayoutMediaLeft = @"media_text";
NSString *const UAInAppMessageBannerContentLayoutMediaRight = @"text_media";

// Constants
NSUInteger const UAInAppMessageBannerDefaultDuration = 30000;
NSUInteger const UAInAppMessageBannerMaxButtons = 2;

@implementation UAInAppMessageBannerDisplayContentBuilder

- (BOOL)applyFromJSON:(id)json error:(NSError * _Nullable *)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    UAInAppMessageTextInfo *heading;
    if (json[UAInAppMessageHeadingKey]) {
        if (![json[UAInAppMessageHeadingKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize text info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }
        heading = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageHeadingKey] error:error];
    }

    UAInAppMessageTextInfo *body;
    if (json[UAInAppMessageBodyKey]) {
        if (![json[UAInAppMessageBodyKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize text info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        body = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageBodyKey] error:error];
    }

    UAInAppMessageMediaInfo *media;
    if (json[UAInAppMessageMediaKey]) {
        if (![json[UAInAppMessageMediaKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize media info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        media = [UAInAppMessageMediaInfo mediaInfoWithJSON:json[UAInAppMessageMediaKey] error:error];
    }


    NSMutableArray<UAInAppMessageButtonInfo *> *buttons = [NSMutableArray array];
    id buttonsJSONArray = json[UAInAppMessageButtonsKey];
    if (buttonsJSONArray) {
        if (![buttonsJSONArray isKindOfClass:[NSArray class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Buttons must contain an array of buttons. Invalid value %@", buttonsJSONArray];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        for (id buttonJSON in buttonsJSONArray) {
            UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithJSON:buttonJSON error:error];

            if (!buttonInfo) {
                return NO;
            }

            [buttons addObject:buttonInfo];
        }

        if (!buttons.count) {
            if (error) {
                NSString *msg = @"Buttons must contain at least 1 button.";
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return NO;
        }
    }

    id buttonLayout = json[UAInAppMessageButtonLayoutKey];
    if (buttonLayout && ![buttonLayout isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Button layout must be a string. Invalid value: %@", buttonLayout];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    id placement = json[UAInAppMessagePlacementKey];
    if (placement && ![placement isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Placement must be a string. Invalid value: %@", placement];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    NSString *contentLayout;
    id layoutContents = json[UAInAppMessageContentLayoutKey];
    if (layoutContents) {
        if (![layoutContents isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Content layout must be a string."];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return NO;
        }

        NSString *layout = [layoutContents lowercaseString];

        if ([UAInAppMessageBannerContentLayoutMediaLeft isEqualToString:layout]) {
            contentLayout = UAInAppMessageBannerContentLayoutMediaLeft;
        } else if ([UAInAppMessageBannerContentLayoutMediaRight isEqualToString:layout]) {
            contentLayout = UAInAppMessageBannerContentLayoutMediaRight;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message content layout: %@", layout];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }
    }

    id duration = json[UAInAppMessageDurationKey];
    if (duration && ![duration isKindOfClass:[NSNumber class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Duration must be a number. Invalid value: %@", duration];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    id backgroundColor = json[UAInAppMessageBackgroundColorKey];
    if (backgroundColor && ![backgroundColor isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Background color must be a string. Invalid value: %@", backgroundColor];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    id dismissButtonColor = json[UAInAppMessageDismissButtonColorKey];
    if (dismissButtonColor && ![dismissButtonColor isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Dismiss button color must be a string. Invalid value: %@", dismissButtonColor];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    id borderRadius = json[UAInAppMessageBorderRadiusKey];
    if (borderRadius && ![borderRadius isKindOfClass:[NSNumber class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Border radius must be a number. Invalid value: %@", borderRadius];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    self.heading = heading;
    self.body = body;
    self.media = media;
    self.buttons = buttons;
    self.buttonLayout = buttonLayout;
    self.placement = placement;
    self.contentLayout = contentLayout;
    self.duration = [duration unsignedIntegerValue];
    self.backgroundColor = backgroundColor;
    self.dismissButtonColor = dismissButtonColor;
    self.borderRadius = [borderRadius unsignedIntegerValue];

    return YES;
}

@end

@implementation UAInAppMessageBannerDisplayContent

+ (instancetype)bannerDisplayContentWithBuilderBlock:(void(^)(UAInAppMessageBannerDisplayContentBuilder *builder))builderBlock {
    UAInAppMessageBannerDisplayContentBuilder *builder = [[UAInAppMessageBannerDisplayContentBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageBannerDisplayContent alloc] initWithBuilder:builder];
}

+ (instancetype)bannerDisplayContentWithJSON:(id)json error:(NSError **)error {
    UAInAppMessageBannerDisplayContentBuilder *builder = [[UAInAppMessageBannerDisplayContentBuilder alloc] init];
    if (![builder applyFromJSON:json error:error]) {
        return nil;
    }

    // Actions
    id actions = json[UAInAppMessageBannerActionsKey];
    if (actions && ![actions isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Actions payload must be a dictionary. Invalid value: %@", actions];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    builder.actions = actions;
    return [[UAInAppMessageBannerDisplayContent alloc] initWithBuilder:builder];
}

- (instancetype)initWithBuilder:(UAInAppMessageBannerDisplayContentBuilder *)builder {
    self = [super self];

    if (![UAInAppMessageBannerDisplayContent validateBuilder:builder]) {
        UA_LDEBUG(@"UAInAppMessageBannerDisplayContent could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }

    if (self) {
        self.heading = builder.heading;
        self.body = builder.body;
        self.media = builder.media;
        self.buttons = builder.buttons;
        self.buttonLayout = builder.buttonLayout ?: UAInAppMessageButtonLayoutSeparate;
        self.placement = builder.placement ?: UAInAppMessageBannerPlacementBottom;
        self.contentLayout = builder.contentLayout ?: UAInAppMessageBannerContentLayoutMediaLeft;
        self.duration = builder.duration ?: UAInAppMessageBannerDefaultDuration;
        self.backgroundColor = builder.backgroundColor ?: @"#FFFFFF"; //White
        self.dismissButtonColor = builder.dismissButtonColor ?: @"#000000"; //Black
        self.borderRadius = builder.borderRadius;
    }

    return self;
}

+ (NSDictionary *)JSONWithBannerDisplayContent:(UAInAppMessageBannerDisplayContent *)displayContent {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    if (!displayContent) {
        return [NSDictionary dictionaryWithDictionary:json];
    }

    json[UAInAppMessageHeadingKey] = [UAInAppMessageTextInfo JSONWithTextInfo:displayContent.heading];
    json[UAInAppMessageBodyKey] = [UAInAppMessageTextInfo JSONWithTextInfo:displayContent.body];
    json[UAInAppMessageMediaKey] = [UAInAppMessageMediaInfo JSONWithMediaInfo:displayContent.media];

    NSMutableArray *buttonsJSONs = [NSMutableArray array];
    for (UAInAppMessageButtonInfo *buttonInfo in displayContent.buttons) {
        [buttonsJSONs addObject:[UAInAppMessageButtonInfo JSONWithButtonInfo:buttonInfo]];
    }
    json[UAInAppMessageButtonsKey] = buttonsJSONs;

    json[UAInAppMessageButtonLayoutKey] = displayContent.buttonLayout;
    json[UAInAppMessagePlacementKey] = displayContent.placement;
    json[UAInAppMessageContentLayoutKey] = displayContent.contentLayout;
    json[UAInAppMessageDurationKey] = [NSNumber numberWithInteger:displayContent.duration];
    json[UAInAppMessageBackgroundColorKey] = displayContent.backgroundColor;
    json[UAInAppMessageDismissButtonColorKey] = displayContent.dismissButtonColor;
    json[UAInAppMessageBorderRadiusKey] = [NSNumber numberWithInteger:displayContent.borderRadius];

    return [NSDictionary dictionaryWithDictionary:json];
}

#pragma mark - Validation

// Validates builder contents for the banner type
+ (BOOL)validateBuilder:(UAInAppMessageBannerDisplayContentBuilder *)builder {
    if (builder.buttonLayout == UAInAppMessageButtonLayoutStacked) {
        UA_LDEBUG(@"Banner style does not support stacked button layouts");
        return NO;
    }

    if (builder.heading == nil && builder.body == nil) {
        UA_LDEBUG(@"Banner must have either its body or heading defined.");
        return NO;
    }

    if (builder.media.type && builder.media.type != UAInAppMessageMediaInfoTypeImage) {
        UA_LDEBUG(@"Banner only supports image media.");
        return NO;
    }

    if (builder.buttons.count > UAInAppMessageBannerMaxButtons) {
        UA_LDEBUG(@"Banner allows a maximum of %lu buttons", (unsigned long)UAInAppMessageBannerMaxButtons);
        return NO;
    }

    return YES;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessageBannerDisplayContent class]]) {
        return NO;
    }

    return [self isEqualToInAppMessageBannerDisplayContent:(UAInAppMessageBannerDisplayContent *)object];
}

- (BOOL)isEqualToInAppMessageBannerDisplayContent:(UAInAppMessageBannerDisplayContent *)content {

    if (content.heading != self.heading && ![self.heading isEqual:content.heading]) {
        return NO;
    }

    if (content.body != self.body && ![self.body isEqual:content.body]) {
        return NO;
    }

    if (content.media != self.media  && ![self.media isEqual:content.media]) {
        return NO;
    }

    if (content.buttons != self.buttons  && ![self.buttons isEqualToArray:content.buttons]) {
        return NO;
    }

    if (content.buttonLayout != self.buttonLayout && ![self.buttonLayout isEqualToString:content.buttonLayout]) {
        return NO;
    }

    if (content.placement != self.placement && ![self.placement isEqualToString:content.placement]) {
        return NO;
    }

    if (content.contentLayout != self.contentLayout  && ![self.contentLayout isEqualToString:content.contentLayout]) {
        return NO;
    }

    if (self.duration != content.duration) {
        return NO;
    }

    if (content.backgroundColor != self.backgroundColor && ![self.backgroundColor isEqualToString:content.backgroundColor]) {
        return NO;
    }

    if (content.dismissButtonColor != self.dismissButtonColor && ![self.dismissButtonColor isEqualToString:content.dismissButtonColor]) {
        return NO;
    }

    if (self.borderRadius != content.borderRadius) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.heading hash];
    result = 31 * result + [self.body hash];
    result = 31 * result + [self.media hash];
    result = 31 * result + [self.buttons hash];
    result = 31 * result + [self.buttonLayout hash];
    result = 31 * result + [self.placement hash];
    result = 31 * result + [self.contentLayout hash];
    result = 31 * result + self.duration;
    result = 31 * result + [self.backgroundColor hash];
    result = 31 * result + [self.dismissButtonColor hash];
    result = 31 * result + self.borderRadius;

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAInAppMessageBannerDisplayContent: %lu", (unsigned long)self.hash];
}

@end

