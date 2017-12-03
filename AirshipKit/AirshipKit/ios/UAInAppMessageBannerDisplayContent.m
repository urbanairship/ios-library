/* Copyright 2017 Urban Airship and Contributors */

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
NSUInteger const UAInAppMessageBannerDefaultDuration = 30000;
NSUInteger const UAInAppMessageBannerMaxButtons = 2;

@interface UAInAppMessageBannerDisplayContent ()

@property(nonatomic, strong) UAInAppMessageTextInfo *heading;
@property(nonatomic, strong) UAInAppMessageTextInfo *body;
@property(nonatomic, strong) UAInAppMessageMediaInfo *media;
@property(nonatomic, copy) NSArray<UAInAppMessageButtonInfo *> *buttons;
@property(nonatomic, copy) NSString *buttonLayout;
@property(nonatomic, copy) NSString *placement;
@property(nonatomic, copy) NSString *contentLayout;
@property(nonatomic, assign) NSUInteger duration;
@property(nonatomic, copy) NSString *backgroundColor;
@property(nonatomic, copy) NSString *dismissButtonColor;
@property(nonatomic, assign) NSUInteger borderRadius;
@property(nonatomic, copy, nullable) NSDictionary *actions;

@end

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

    UAInAppMessageTextInfo *heading = nil;
    if (json[UAInAppMessageHeadingKey]) {
        heading = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageHeadingKey] error:error];

        if (!heading) {
            return NO;
        }
    }

    UAInAppMessageTextInfo *body = nil;
    if (json[UAInAppMessageBodyKey]) {
        body = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageBodyKey] error:error];

        if (!body) {
            return NO;
        }
    }

    UAInAppMessageMediaInfo *media = nil;
    if (json[UAInAppMessageMediaKey]) {
        media = [UAInAppMessageMediaInfo mediaInfoWithJSON:json[UAInAppMessageMediaKey] error:error];

        if (!media) {
            return NO;
        }
    }

    NSMutableArray<UAInAppMessageButtonInfo *> *buttons = [NSMutableArray array];
    id buttonsJSONArray = json[UAInAppMessageButtonsKey];
    if (!buttonsJSONArray || ![buttonsJSONArray isKindOfClass:[NSArray class]]) {
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
            NSString *msg = @"Buttons contain at least 1 button.";
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return NO;
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
    if (json[UAInAppMessageContentLayoutKey]) {
        NSString *layout = [json[UAInAppMessageContentLayoutKey] lowercaseString];

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
    if (borderRadius && ![duration isKindOfClass:[NSNumber class]]) {
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
    if (self) {
        self.heading = builder.heading;
        self.body = builder.body;
        self.media = builder.media;
        self.buttons = builder.buttons;
        self.buttonLayout = builder.buttonLayout;
        self.placement = builder.placement;
        self.contentLayout = builder.contentLayout;
        self.duration = builder.duration;
        self.backgroundColor = builder.backgroundColor;
        self.dismissButtonColor = builder.dismissButtonColor;
        self.borderRadius = builder.borderRadius;
    }

    return self;
}

+ (NSDictionary *)JSONWithBannerDisplayContent:(UAInAppMessageBannerDisplayContent *_Nonnull)displayContent {

    NSMutableDictionary *json = [NSMutableDictionary dictionary];

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
    json[UAInAppMessageDurationKey] = [NSNumber numberWithInteger:displayContent.duration ];
    json[UAInAppMessageBackgroundColorKey] = displayContent.backgroundColor;
    json[UAInAppMessageDismissButtonColorKey] = displayContent.dismissButtonColor;
    json[UAInAppMessageBorderRadiusKey] = [NSNumber numberWithInteger:displayContent.borderRadius];

    return [NSDictionary dictionaryWithDictionary:json];
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

    if (![self.heading isEqual:content.heading]) {
        return NO;
    }

    if (![self.body isEqual:content.body]) {
        return NO;
    }

    if (![self.media isEqual:content.media]) {
        return NO;
    }

    if (self.buttons != content.buttons && ![self.buttons isEqualToArray:content.buttons]) {
        return NO;
    }

    if (![self.buttonLayout isEqualToString:content.buttonLayout]) {
        return NO;
    }

    if (![self.placement isEqualToString:content.placement]) {
        return NO;
    }

    if (![self.contentLayout isEqualToString:content.contentLayout]) {
        return NO;
    }

    if (self.duration != content.duration) {
        return NO;
    }

    if (![self.backgroundColor isEqualToString:content.backgroundColor]) {
        return NO;
    }

    if (![self.dismissButtonColor isEqualToString:content.dismissButtonColor]) {
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

