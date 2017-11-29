/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageMediaInfo.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageMediaInfoTypeImage = @"image";
NSString *const UAInAppMessageMediaInfoTypeVideo = @"video";
NSString *const UAInAppMessageMediaInfoTypeYouTube = @"youtube";

NSString *const UAInAppMessageMediaInfoDomain = @"com.urbanairship.in_app_message_media_info";

NSString *const UAInAppMessageMediaInfoURLKey = @"url";
NSString *const UAInAppMessageMediaInfoTypeKey = @"type";

@interface UAInAppMessageMediaInfo ()
@property(nonatomic, copy) NSString *url;
@property(nonatomic, copy) NSString *type;
@end

@implementation UAInAppMessageMediaInfoBuilder
@end

@implementation UAInAppMessageMediaInfo

- (instancetype)initWithBuilder:(UAInAppMessageMediaInfoBuilder *)builder {
    self = [super self];
    if (self) {
        self.url = builder.url;
        self.type = builder.type;
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
    if (json[UAInAppMessageMediaInfoTypeKey]) {
        NSString *type = [json[UAInAppMessageMediaInfoTypeKey] lowercaseString];

        if ([UAInAppMessageMediaInfoTypeImage isEqualToString:type]) {
            mediaType = UAInAppMessageMediaInfoTypeImage;
        } else if ([UAInAppMessageMediaInfoTypeVideo isEqualToString:type]) {
            mediaType = UAInAppMessageMediaInfoTypeVideo;
        } else if ([UAInAppMessageMediaInfoTypeYouTube isEqualToString:type]) {
            mediaType = UAInAppMessageMediaInfoTypeYouTube;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message media type: %@", type];
                *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                              code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }
    }

    return [UAInAppMessageMediaInfo mediaInfoWithBuilderBlock:^(UAInAppMessageMediaInfoBuilder * _Nonnull builder) {
        builder.url = url;
        builder.type = mediaType;
    }];
}

+ (NSDictionary *)JSONWithMediaInfo:(UAInAppMessageMediaInfo *)mediaInfo {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    json[UAInAppMessageMediaInfoURLKey] = mediaInfo.url;
    json[UAInAppMessageMediaInfoTypeKey] = mediaInfo.type;

    return [NSDictionary dictionaryWithDictionary:json];
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

    if (![self.url isEqualToString:info.url]) {
        return NO;
    }

    if (![self.type isEqualToString:info.type]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.url hash];
    result = 31 * result + [self.type hash];

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAInAppMessageMediaInfo: %lu", (unsigned long)self.hash];
}

@end

NS_ASSUME_NONNULL_END

