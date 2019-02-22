/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageMediaInfo+Internal.h"
#import "UAGlobal.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const UAInAppMessageMediaInfoDomain = @"com.urbanairship.in_app_message_media_info";

// JSON keys
NSString *const UAInAppMessageMediaInfoURLKey = @"url";
NSString *const UAInAppMessageMediaInfoTypeKey = @"type";
NSString *const UAInAppMessageMediaInfoDescriptionKey = @"description";

// Media JSON types
NSString *const UAInAppMessageMediaInfoTypeImageValue = @"image";
NSString *const UAInAppMessageMediaInfoTypeVideoValue = @"video";
NSString *const UAInAppMessageMediaInfoTypeYouTubeValue = @"youtube";

@interface UAInAppMessageMediaInfo ()
@property(nonatomic, copy) NSString *url;
@property(nonatomic, assign) UAInAppMessageMediaInfoType type;
@property(nonatomic, copy) NSString *contentDescription;
@end


@implementation UAInAppMessageMediaInfo

- (instancetype)initWithURL:(NSString *)url
              contentDescription:(NSString *)contentDescription
                       type:(UAInAppMessageMediaInfoType)type {

    self = [super init];

    if (self) {
        self.url = url;
        self.type = type;
        self.contentDescription = contentDescription;
    }

    return self;
}


+ (instancetype)mediaInfoWithURL:(NSString *)url
              contentDescription:(NSString *)contentDescription
                            type:(UAInAppMessageMediaInfoType)type {

    return [[self alloc] initWithURL:url contentDescription:contentDescription type:type];
}

+ (nullable instancetype)mediaInfoWithJSON:(id)json error:(NSError * _Nullable *)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize media info object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                          code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }

    id urlText = json[UAInAppMessageMediaInfoURLKey];
    if (![urlText isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message media URL is required and must be a string. Invalid value: %@", urlText];
            *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                          code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    id typeString = json[UAInAppMessageMediaInfoTypeKey];
    if (![typeString isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Media type must be a string."];
            *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                          code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }

    typeString = [typeString lowercaseString];
    UAInAppMessageMediaInfoType type;

    if ([UAInAppMessageMediaInfoTypeImageValue isEqualToString:typeString]) {
        type = UAInAppMessageMediaInfoTypeImage;
    } else if ([UAInAppMessageMediaInfoTypeVideoValue isEqualToString:typeString]) {
        type = UAInAppMessageMediaInfoTypeVideo;
    } else if ([UAInAppMessageMediaInfoTypeYouTubeValue isEqualToString:typeString]) {
        type = UAInAppMessageMediaInfoTypeYouTube;
    } else {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Invalid in-app message media type: %@", typeString];
            *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                          code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }

    id descriptionText = json[UAInAppMessageMediaInfoDescriptionKey];
    if (![descriptionText isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message media description must be a string. Invalid value: %@", descriptionText];
            *error =  [NSError errorWithDomain:UAInAppMessageMediaInfoDomain
                                          code:UAInAppMessageMediaInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    return [UAInAppMessageMediaInfo mediaInfoWithURL:urlText
                                  contentDescription:descriptionText
                                                type:type];
}

- (NSDictionary *)toJSON {
    return @{
             UAInAppMessageMediaInfoURLKey: self.url,
             UAInAppMessageMediaInfoDescriptionKey: self.contentDescription,
             UAInAppMessageMediaInfoTypeKey: [UAInAppMessageMediaInfo typeStringForType:self.type] };
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

    if (![self.contentDescription isEqualToString:info.contentDescription]) {
        return NO;
    }

    if (info.type != self.type) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.url hash];
    result = 31 * result + self.type;
    result = 31 * result + [self.contentDescription hash];

    return result;
}

+ (NSString *)typeStringForType:(UAInAppMessageMediaInfoType)type {
    switch (type) {
        case UAInAppMessageMediaInfoTypeImage:
            return UAInAppMessageMediaInfoTypeImageValue;
            break;
        case UAInAppMessageMediaInfoTypeVideo:
            return UAInAppMessageMediaInfoTypeVideoValue;
            break;
        case UAInAppMessageMediaInfoTypeYouTube:
            return UAInAppMessageMediaInfoTypeYouTubeValue;
            break;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAInAppMessageMediaInfo: %@>", [self toJSON]];
}

@end

NS_ASSUME_NONNULL_END

