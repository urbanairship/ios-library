/* Copyright Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageTextInfo+Internal.h"
#import "UAInAppMessageButtonInfo+Internal.h"
#import "UAInAppMessageMediaInfo+Internal.h"
#import "UAInAppMessageDisplayContent.h"
#import "UAColorUtils+Internal.h"
#import "UAUtils+Internal.h"

// JSON keys
NSString *const UAInAppMessageBannerActionsKey = @"actions";
NSString *const UAInAppMessageBannerDisplayContentDomain = @"com.urbanairship.banner_display_content";
NSString *const UAInAppMessageBannerPlacementTopValue = @"top";
NSString *const UAInAppMessageBannerPlacementBottomValue = @"bottom";
NSString *const UAInAppMessageBannerContentLayoutMediaLeftValue = @"media_left";
NSString *const UAInAppMessageBannerContentLayoutMediaRightValue = @"media_right";

// Constants
NSTimeInterval const UAInAppMessageBannerDefaultDuration = 30;
NSTimeInterval const UAInAppMessageBannerMinDuration = 0;
NSTimeInterval const UAInAppMessageBannerMaxDuration = 120;
NSUInteger const UAInAppMessageBannerMaxButtons = 2;

@implementation UAInAppMessageBannerDisplayContentBuilder

// set default values for properties
- (instancetype)init {
    self = [super init];

    if (self) {
        self.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        self.placement = UAInAppMessageBannerPlacementBottom;
        self.contentLayout = UAInAppMessageBannerContentLayoutTypeMediaLeft;
        self.durationSeconds = UAInAppMessageBannerDefaultDuration;
        self.backgroundColor = [UIColor whiteColor];
        self.dismissButtonColor = [UIColor blackColor];
    }

    return self;
}

- (instancetype)initWithDisplayContent:(UAInAppMessageBannerDisplayContent *)content {
    self = [super init];

    if (self) {
        self.heading = content.heading;
        self.body = content.body;
        self.media = content.media;
        self.buttons = content.buttons;
        self.buttonLayout = content.buttonLayout;
        self.placement = content.placement;
        self.contentLayout = content.contentLayout;
        self.durationSeconds = content.durationSeconds;
        self.backgroundColor = content.backgroundColor;
        self.dismissButtonColor = content.dismissButtonColor;
        self.borderRadiusPoints = content.borderRadiusPoints;
        self.actions = content.actions;
    }

    return self;
}

+ (instancetype)builderWithDisplayContent:(UAInAppMessageBannerDisplayContent *)content {
    return [[self alloc] initWithDisplayContent:content];
}

- (BOOL)isValid {
    if (self.heading == nil && self.body == nil) {
        UA_LERR(@"Banner must have either its body or heading defined.");
        return NO;
    }

    if (self.media.type && self.media.type != UAInAppMessageMediaInfoTypeImage) {
        UA_LERR(@"Banner only supports image media.");
        return NO;
    }

    if (self.buttons.count > UAInAppMessageBannerMaxButtons) {
        UA_LERR(@"Banner allows a maximum of %lu buttons", (unsigned long)UAInAppMessageBannerMaxButtons);
        return NO;
    }

    return YES;
}

- (NSUInteger)borderRadius {
    return self.borderRadiusPoints;
}

- (void)setBorderRadius:(NSUInteger)borderRadius {
    self.borderRadiusPoints = borderRadius;
}

- (NSUInteger)duration {
    return self.durationSeconds;
}

- (void)setDuration:(NSUInteger)duration {
    self.durationSeconds = duration;
}

@end

@interface UAInAppMessageBannerDisplayContent()
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *body;
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;
@property(nonatomic, strong, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;
@property(nonatomic, assign) UAInAppMessageBannerPlacementType placement;
@property(nonatomic, assign) UAInAppMessageBannerContentLayoutType contentLayout;
@property(nonatomic, assign) NSTimeInterval durationSeconds;
@property(nonatomic, assign) CGFloat borderRadiusPoints;
@property(nonatomic, strong, nonnull) UIColor *backgroundColor;
@property(nonatomic, strong, nonnull) UIColor *dismissButtonColor;
@property(nonatomic, strong, nullable) NSDictionary *actions;
@end

@implementation UAInAppMessageBannerDisplayContent

+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageBannerDisplayContentBuilder *builder))builderBlock {
    UAInAppMessageBannerDisplayContentBuilder *builder = [[UAInAppMessageBannerDisplayContentBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageBannerDisplayContent alloc] initWithBuilder:builder];
}

+ (nullable instancetype)displayContentWithJSON:(id)json error:(NSError **)error {
    UAInAppMessageBannerDisplayContentBuilder *builder = [[UAInAppMessageBannerDisplayContentBuilder alloc] init];
    
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }
    
    if (json[UAInAppMessageHeadingKey]) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageHeadingKey] error:error];

        if (!builder.heading) {
            return nil;
        }
    }
    
    if (json[UAInAppMessageBodyKey]) {
        builder.body = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageBodyKey] error:error];

        if (!builder.body) {
            return nil;
        }
    }
    
    if (json[UAInAppMessageMediaKey]) {
        builder.media = [UAInAppMessageMediaInfo mediaInfoWithJSON:json[UAInAppMessageMediaKey] error:error];

        if (!builder.media) {
            return nil;
        }
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
            return nil;
        }
        
        builder.buttons = [NSMutableArray array];
        
        for (id buttonJSON in buttonsJSONArray) {
            UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithJSON:buttonJSON error:error];
            
            if (!buttonInfo) {
                return nil;
            }
            
            [buttons addObject:buttonInfo];
        }
        builder.buttons = [NSArray arrayWithArray:buttons];
    }
    
    id buttonLayoutValue = json[UAInAppMessageButtonLayoutKey];
    if (buttonLayoutValue) {
        if (![buttonLayoutValue isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Button layout must be a string. Invalid value: %@", buttonLayoutValue];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        if ([UAInAppMessageButtonLayoutJoinedValue isEqualToString:buttonLayoutValue]) {
            builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;
        } else if ([UAInAppMessageButtonLayoutSeparateValue isEqualToString:buttonLayoutValue]) {
            builder.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        } else if ([UAInAppMessageButtonLayoutStackedValue isEqualToString:buttonLayoutValue]) {
            builder.buttonLayout = UAInAppMessageButtonLayoutTypeStacked;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app button layout type: %@", buttonLayoutValue];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
    }
    
    id placementValue = json[UAInAppMessagePlacementKey];
    if (placementValue) {
        if (![placementValue isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Placement must be a string. Invalid value: %@", placementValue];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        } else {
            if ([UAInAppMessageBannerPlacementTopValue isEqualToString:placementValue]) {
                builder.placement = UAInAppMessageBannerPlacementTop;
            } else if ([UAInAppMessageBannerPlacementBottomValue isEqualToString:placementValue]) {
                builder.placement = UAInAppMessageBannerPlacementBottom;
            } else {
                if (error) {
                    NSString *msg = [NSString stringWithFormat:@"Placement must be a string. Invalid value: %@", placementValue];
                    *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                                  code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                              userInfo:@{NSLocalizedDescriptionKey:msg}];
                }
                return nil;
            }
        }
    }
    
    id layoutContents = json[UAInAppMessageContentLayoutKey];
    if (layoutContents) {
        if (![layoutContents isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Content layout must be a string."];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        
        layoutContents = [layoutContents lowercaseString];
        
        if ([UAInAppMessageBannerContentLayoutMediaLeftValue isEqualToString:layoutContents]) {
            builder.contentLayout = UAInAppMessageBannerContentLayoutTypeMediaLeft;
        } else if ([UAInAppMessageBannerContentLayoutMediaRightValue isEqualToString:layoutContents]) {
            builder.contentLayout = UAInAppMessageBannerContentLayoutTypeMediaRight;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message content layout: %@", layoutContents];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
    }
    
    id durationValue = json[UAInAppMessageDurationKey];
    if (durationValue) {
        if (![durationValue isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Duration must be a number. Invalid value: %@", durationValue];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.durationSeconds = [durationValue doubleValue];
    }
    
    id backgroundColorHex = json[UAInAppMessageBackgroundColorKey];
    if (backgroundColorHex) {
        if (![backgroundColorHex isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Background color must be a string. Invalid value: %@", backgroundColorHex];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.backgroundColor = [UAColorUtils colorWithHexString:backgroundColorHex];
    }
    
    id dismissButtonColorHex = json[UAInAppMessageDismissButtonColorKey];
    if (dismissButtonColorHex) {
        if (![dismissButtonColorHex isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Dismiss button color must be a string. Invalid value: %@", dismissButtonColorHex];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.dismissButtonColor = [UAColorUtils colorWithHexString:dismissButtonColorHex];
    }
    
    id borderRadius = json[UAInAppMessageBorderRadiusKey];
    if (borderRadius) {
        if (![borderRadius isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Border radius must be a number. Invalid value: %@", borderRadius];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.borderRadiusPoints = [borderRadius doubleValue];
    }

    id actions = json[UAInAppMessageBannerActionsKey];
    if (actions) {
        if (![actions isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Actions payload must be a dictionary. Invalid value: %@", actions];
                *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                              code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.actions = actions;
    }

    if (![builder isValid]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Invalid banner display content: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageBannerDisplayContentDomain
                                          code:UAInAppMessageBannerDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    
    return [[UAInAppMessageBannerDisplayContent alloc] initWithBuilder:builder];
}

- (nullable instancetype)initWithBuilder:(UAInAppMessageBannerDisplayContentBuilder *)builder {
    self = [super init];

    if (![builder isValid]) {
        UA_LERR(@"UAInAppMessageBannerDisplayContent could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }

    if (self) {
        self.heading = builder.heading;
        self.body = builder.body;
        self.media = builder.media;
        self.buttons = builder.buttons;
        self.buttonLayout = builder.buttonLayout;
        self.placement = builder.placement;
        self.contentLayout = builder.contentLayout;
        self.durationSeconds = builder.durationSeconds;
        self.backgroundColor = builder.backgroundColor;
        self.dismissButtonColor = builder.dismissButtonColor;
        self.borderRadiusPoints = builder.borderRadiusPoints;
        self.actions = builder.actions;
    }

    return self;
}

- (nullable UAInAppMessageBannerDisplayContent *)extend:(void(^)(UAInAppMessageBannerDisplayContentBuilder *builder))builderBlock {
    if (builderBlock) {
        UAInAppMessageBannerDisplayContentBuilder *builder = [UAInAppMessageBannerDisplayContentBuilder builderWithDisplayContent:self];
        builderBlock(builder);
        return [[UAInAppMessageBannerDisplayContent alloc] initWithBuilder:builder];
    }

    UA_LDEBUG(@"Extended %@ with nil builderBlock. Returning self.", self);
    return self;
}

- (NSDictionary *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    [json setValue:[self.heading toJSON] forKey:UAInAppMessageHeadingKey];
    [json setValue:[self.body toJSON] forKey:UAInAppMessageBodyKey];
    [json setValue:[self.media toJSON] forKey:UAInAppMessageMediaKey];
    [json setValue:@(self.durationSeconds) forKey:UAInAppMessageDurationKey];
    [json setValue:@(self.borderRadiusPoints) forKey:UAInAppMessageBorderRadiusKey];
    [json setValue:[UAColorUtils hexStringWithColor:self.backgroundColor] forKey:UAInAppMessageBackgroundColorKey];
    [json setValue:[UAColorUtils hexStringWithColor:self.dismissButtonColor] forKey:UAInAppMessageDismissButtonColorKey];
    [json setValue:self.actions forKey:UAInAppMessageBannerActionsKey];

    NSMutableArray *buttonsJSONs = [NSMutableArray array];
    for (UAInAppMessageButtonInfo *buttonInfo in self.buttons) {
        [buttonsJSONs addObject:[buttonInfo toJSON]];
    }

    if (buttonsJSONs.count) {
        [json setValue:buttonsJSONs forKey:UAInAppMessageButtonsKey];
    }
    
    switch (self.buttonLayout) {
        case UAInAppMessageButtonLayoutTypeStacked:
            [json setValue:UAInAppMessageButtonLayoutStackedValue forKey:UAInAppMessageButtonLayoutKey];
            break;
        case UAInAppMessageButtonLayoutTypeSeparate:
            [json setValue:UAInAppMessageButtonLayoutSeparateValue forKey:UAInAppMessageButtonLayoutKey];
            break;
        case UAInAppMessageButtonLayoutTypeJoined:
            [json setValue:UAInAppMessageButtonLayoutJoinedValue forKey:UAInAppMessageButtonLayoutKey];
            break;
    }

    switch (self.placement) {
        case UAInAppMessageBannerPlacementTop:
            [json setValue:UAInAppMessageBannerPlacementTopValue forKey:UAInAppMessagePlacementKey];
            break;
        case UAInAppMessageBannerPlacementBottom:
            [json setValue:UAInAppMessageBannerPlacementBottomValue forKey:UAInAppMessagePlacementKey];
            break;
    }

    switch(self.contentLayout) {
        case UAInAppMessageBannerContentLayoutTypeMediaLeft:
            [json setValue:UAInAppMessageBannerContentLayoutMediaLeftValue forKey:UAInAppMessageContentLayoutKey];
            break;
        case UAInAppMessageBannerContentLayoutTypeMediaRight:
            [json setValue:UAInAppMessageBannerContentLayoutMediaRightValue forKey:UAInAppMessageContentLayoutKey];
            break;
    }

    return [json copy];
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

    if (content.buttonLayout != self.buttonLayout) {
        return NO;
    }

    if (content.placement != self.placement) {
        return NO;
    }

    if (content.contentLayout != self.contentLayout) {
        return NO;
    }

    if (![UAUtils float:self.durationSeconds isEqualToFloat:content.durationSeconds withAccuracy:0.01]) {
        return NO;
    }

    // Unfortunately, UIColor won't compare across color spaces. It works to convert them to hex and then compare them.
    if (content.backgroundColor != self.backgroundColor && ![[UAColorUtils hexStringWithColor:self.backgroundColor] isEqualToString:[UAColorUtils hexStringWithColor:content.backgroundColor]]) {
        return NO;
    }

    if (content.dismissButtonColor != self.dismissButtonColor && ![[UAColorUtils hexStringWithColor:self.dismissButtonColor] isEqualToString:[UAColorUtils hexStringWithColor:content.dismissButtonColor]]) {
        return NO;
    }

    if (![UAUtils float:self.borderRadiusPoints isEqualToFloat:content.borderRadiusPoints withAccuracy:0.01]) {
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
    result = 31 * result + self.buttonLayout;
    result = 31 * result + self.placement;
    result = 31 * result + self.contentLayout;
    result = 31 * result + self.durationSeconds;
    result = 31 * result + [[UAColorUtils hexStringWithColor:self.backgroundColor] hash];
    result = 31 * result + [[UAColorUtils hexStringWithColor:self.dismissButtonColor] hash];
    result = 31 * result + self.borderRadiusPoints;

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAInAppMessageBannerDisplayContent: %@>", [self toJSON]];
}

-(UAInAppMessageDisplayType)displayType {
    return UAInAppMessageDisplayTypeBanner;
}

- (NSUInteger)borderRadius {
    return self.borderRadiusPoints;
}

- (NSUInteger)duration {
    return self.durationSeconds;
}

@end

