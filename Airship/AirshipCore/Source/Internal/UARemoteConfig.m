/* Copyright Airship and Contributors */

#import "UARemoteConfig.h"
#import "UAGlobal.h"

static NSString * const UARemoteDataURLKey = @"remote_data_url";
static NSString * const UADeviceAPIURLKey = @"device_api_url";
static NSString * const UAAnalyticsURLKey = @"analytics_url";
static NSString * const UAChatURLKey = @"chat_url";
static NSString * const UAChatWebSocketURLKey = @"chat_web_socket_url";

@implementation UARemoteConfig

- (instancetype)initWithRemoteDataURL:(NSString *)remoteDataURL
                         deviceAPIURL:(NSString *)deviceAPIURL
                         analyticsURL:(NSString *)analyticsURL
                              chatURL:(NSString *)chatURL
                     chatWebSocketURL:(NSString *)chatWebSocketURL {
  
    self = [super init];
 
    if (self) {
        self.remoteDataURL = remoteDataURL;
        self.deviceAPIURL = deviceAPIURL;
        self.analyticsURL = analyticsURL;
        self.chatURL = chatURL;
        self.chatWebSocketURL = chatWebSocketURL;
    }
   
    return self;
}

+ (instancetype)configWithRemoteDataURL:(NSString *)remoteDataURL
                           deviceAPIURL:(NSString *)deviceAPIURL
                           analyticsURL:(NSString *)analyticsURL
                                chatURL:(NSString *)chatURL
                       chatWebSocketURL:(NSString *)chatWebSocketURL {
    
    return [[UARemoteConfig alloc] initWithRemoteDataURL:remoteDataURL
                                            deviceAPIURL:deviceAPIURL
                                            analyticsURL:analyticsURL
                                                 chatURL:chatURL
                                        chatWebSocketURL:chatWebSocketURL];
}

+ (instancetype)configWithRemoteData:(NSDictionary *)remoteConfigData {
    NSString *deviceAPIURL = remoteConfigData[UADeviceAPIURLKey];
    NSString *remoteDataURL = remoteConfigData[UARemoteDataURLKey];
    NSString *analyticsURL = remoteConfigData[UAAnalyticsURLKey];
    NSString *chatURL = remoteConfigData[UAChatURLKey];
    NSString *chatWebSocketURL = remoteConfigData[UAChatWebSocketURLKey];

    return [UARemoteConfig configWithRemoteDataURL:remoteDataURL
                                      deviceAPIURL:deviceAPIURL
                                      analyticsURL:analyticsURL
                                           chatURL:chatURL
                                  chatWebSocketURL:chatWebSocketURL];
}

- (void)setAnalyticsURL:(NSString *)analyticsURL {
    _analyticsURL = [self normalizeURL:analyticsURL];
}

- (void)setDeviceAPIURL:(NSString *)deviceAPIURL {
    _deviceAPIURL = [self normalizeURL:deviceAPIURL];
}

- (void)setRemoteDataURL:(NSString *)remoteDataURL {
    _remoteDataURL = [self normalizeURL:remoteDataURL];
}

- (void)setChatURL:(NSString *)chatURL {
    _chatURL = [self normalizeURL:chatURL];
}

- (void)setChatWebSocketURL:(NSString *)chatWebSocketURL {
    _chatWebSocketURL = [self normalizeURL:chatWebSocketURL];
}

- (NSString *)normalizeURL:(NSString *)urlString {
    //Any appending url starts with a beginning /, so make sure the base url does not
    if ([urlString hasSuffix:@"/"]) {
        UA_LWARN(@"URL %@ ends with a trailing slash, stripping ending slash.", urlString);
        return [urlString substringWithRange:NSMakeRange(0, urlString.length - 1)];
    } else {
        return [urlString copy];
    }
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    } else if (![super isEqual:other]) {
        return NO;
    } else {
        return [self isEqualToRemoteURLConfig:other];
    }
}

- (BOOL)isEqualToRemoteURLConfig:(nullable UARemoteConfig *)other {
    if ((self.deviceAPIURL != other.deviceAPIURL) && ![self.deviceAPIURL isEqualToString:other.deviceAPIURL]) {
        return NO;
    }

    if ((self.analyticsURL != other.analyticsURL) && ![self.analyticsURL isEqualToString:other.analyticsURL]) {
        return NO;
    }

    if ((self.remoteDataURL != other.remoteDataURL) && ![self.remoteDataURL isEqualToString:other.remoteDataURL]) {
        return NO;
    }

    if ((self.chatURL != other.chatURL) && ![self.chatURL isEqualToString:other.chatURL]) {
        return NO;
    }

    if ((self.chatWebSocketURL != other.chatWebSocketURL) && ![self.chatWebSocketURL isEqualToString:other.chatWebSocketURL]) {
        return NO;
    }
    
    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.deviceAPIURL hash];
    result = 31 * result + [self.analyticsURL hash];
    result = 31 * result + [self.remoteDataURL hash];
    result = 31 * result + [self.chatURL hash];
    result = 31 * result + [self.chatWebSocketURL hash];
    return result;
}

@end
