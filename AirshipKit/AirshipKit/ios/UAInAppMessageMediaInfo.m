/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageMediaInfo.h"
#import "UAGlobal.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageMediaInfoTypeImage = @"image";
NSString *const UAInAppMessageMediaInfoTypeVideo = @"video";
NSString *const UAInAppMessageMediaInfoTypeYouTube = @"youtube";

NSString *const UAInAppMessageMediaInfoDomain = @"com.urbanairship.in_app_message_media_info";

NSString *const UAInAppMessageMediaInfoURLKey = @"url";
NSString *const UAInAppMessageMediaInfoTypeKey = @"type";
NSString *const UAInAppMessageMediaInfoDescriptionKey = @"description";


@interface UAInAppMessageMediaInfo ()
@property(nonatomic, copy) NSString *url;
@property(nonatomic, copy) NSString *type;
@property(nonatomic, copy) NSString *mediaDescription;
@end

@implementation UAInAppMessageMediaInfoBuilder
@end

@implementation UAInAppMessageMediaInfo

- (instancetype)initWithBuilder:(UAInAppMessageMediaInfoBuilder *)builder {
    self = [super self];

    if (![UAInAppMessageMediaInfo validateBuilder:builder]) {
        UA_LDEBUG(@"UAInAppMessageMediaInfo could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }

    if (self) {
        self.url = builder.url;
        self.type = builder.type;
        self.mediaDescription = builder.mediaDescription;
    }

    return self;
}

+ (nullable instancetype)mediaInfoWithBuilderBlock:(void(^)(UAInAppMessageMediaInfoBuilder *builder))builderBlock {
    UAInAppMessageMediaInfoBuilder *builder = [[UAInAppMessageMediaInfoBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageMediaInfo alloc] initWithBuilder:builder];
}

+ (nullable instancetype)mediaInfoWithJSON:(id)json error:(NSError * _Nullable *)error {

    NSString *url;
    id urlText = json[UAInAppMessageMediaInfoURLKey];
    if (urlText && ![urlText isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message media URL must be a string. Invalid value: %@", urlText];
            *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                          code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }
    url = urlText;

    NSString *mediaType;
    id mediaContents = json[UAInAppMessageMediaInfoTypeKey];
    if (mediaContents) {
        if (![mediaContents isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Media type must be a string."];
                *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                              code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }

        mediaType = [mediaContents lowercaseString];

        if ([UAInAppMessageMediaInfoTypeImage isEqualToString:mediaType]) {
            mediaType = UAInAppMessageMediaInfoTypeImage;
        } else if ([UAInAppMessageMediaInfoTypeVideo isEqualToString:mediaType]) {
            mediaType = UAInAppMessageMediaInfoTypeVideo;
        } else if ([UAInAppMessageMediaInfoTypeYouTube isEqualToString:mediaType]) {
            mediaType = UAInAppMessageMediaInfoTypeYouTube;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message media type: %@", mediaType];
                *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                              code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }
    }

    NSString *description;
    id descriptionText = json[UAInAppMessageMediaInfoDescriptionKey];
    if (descriptionText && ![descriptionText isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message media description must be a string. Invalid value: %@", descriptionText];
            *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                          code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }
    description = descriptionText;

    return [UAInAppMessageMediaInfo mediaInfoWithBuilderBlock:^(UAInAppMessageMediaInfoBuilder * _Nonnull builder) {
        builder.url = url;
        builder.type = mediaType;
        builder.mediaDescription = description;
    }];
}

+ (NSDictionary *)JSONWithMediaInfo:(UAInAppMessageMediaInfo *)mediaInfo {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    json[UAInAppMessageMediaInfoURLKey] = mediaInfo.url;
    json[UAInAppMessageMediaInfoTypeKey] = mediaInfo.type;
    json[UAInAppMessageMediaInfoDescriptionKey] = mediaInfo.mediaDescription;

    return [NSDictionary dictionaryWithDictionary:json];
}

#pragma mark - Validation

// Validates builder contents for the media type
+ (BOOL)validateBuilder:(UAInAppMessageMediaInfoBuilder *)builder {
    if (!builder.url) {
        UA_LDEBUG(@"In-app media infos require a url");
        return NO;
    }

    if (!builder.type) {
        UA_LDEBUG(@"In-app media infos require a media type");
        return NO;
    }

    return YES;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessageMediaInfo class]]) {
        return NO;
    }

    return [self isEqualToInAppMessageMediaInfo:(UAInAppMessageMediaInfo *)object];
}

- (BOOL)isEqualToInAppMessageMediaInfo:(UAInAppMessageMediaInfo *)info {

    if ((info.url && !self.url) || (!info.url && self.url) || (self.url && ![self.url isEqualToString:info.url])) {
        return NO;
    }

    if ((info.type && !self.type) || (!info.type && self.type) || (self.type && ![self.type isEqualToString:info.type])) {
        return NO;
    }

    if ((info.mediaDescription && !self.mediaDescription) ||
        (!info.mediaDescription && self.mediaDescription) ||
        (self.mediaDescription && ![self.mediaDescription isEqualToString:info.mediaDescription])) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.url hash];
    result = 31 * result + [self.type hash];
    result = 31 * result + [self.mediaDescription hash];

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAInAppMessageMediaInfo: %lu", (unsigned long)self.hash];
}

@end

NS_ASSUME_NONNULL_END

