
#import "UADeviceRegistrationPayload.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAChannelRegistrationPayload.h"

@interface UADeviceRegistrationPayload()
@property (nonatomic, strong) NSDictionary *payloadDictionary;
@end

@implementation UADeviceRegistrationPayload

- (instancetype)initWithAlias:(NSString *)alias
           withTags:(NSArray *)tags
       withTimeZone:(NSString *)timeZone
      withQuietTime:(NSDictionary *)quietTime
          withBadge:(NSNumber *)badge {

    self = [super init];
    if (self) {
        self.payloadDictionary = [NSMutableDictionary dictionary];

        if (alias) {
            [self.payloadDictionary setValue:alias forKey:kUAPushAliasJSONKey];
        }

        if (tags) {
            [self.payloadDictionary setValue:tags forKey:kUAPushMultipleTagsJSONKey];
        }

        if (timeZone) {
            [self.payloadDictionary setValue:timeZone forKey:kUAPushTimeZoneJSONKey];
        }

        if (quietTime) {
            [self.payloadDictionary setValue:quietTime forKey:kUAPushQuietTimeJSONKey];
        }

        if (badge) {
            [self.payloadDictionary setValue:badge forKey:kUAPushBadgeJSONKey];
        }
    }

    return self;
}

+ (instancetype)payloadWithAlias:(NSString *)alias
              withTags:(NSArray *)tags
          withTimeZone:(NSString *)timeZone
         withQuietTime:(NSDictionary *)quietTime
             withBadge:(NSNumber *)badge {

    return [[self alloc] initWithAlias:alias
                              withTags:tags
                          withTimeZone:timeZone
                         withQuietTime:quietTime
                             withBadge:badge];
}

+ (instancetype)payloadFromChannelRegistrationPayload:(UAChannelRegistrationPayload *)payload {
    NSArray *tags = payload.setTags ? payload.tags : nil;
    return [self payloadWithAlias:payload.alias
                         withTags:tags
                     withTimeZone:payload.timeZone
                    withQuietTime:payload.quietTime
                        withBadge:payload.badge];
}

- (NSDictionary *)asDictionary {
    return [self.payloadDictionary copy];
}

- (NSString *)asJSONString {
    return [NSJSONSerialization stringWithObject:self.payloadDictionary];
}

- (NSData *)asJSONData {
    return [NSJSONSerialization dataWithJSONObject:self.payloadDictionary
                                           options:0
                                             error:nil];
}


@end
