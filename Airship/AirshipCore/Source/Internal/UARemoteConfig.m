/* Copyright Airship and Contributors */

#import "UARemoteConfig.h"

static NSString * const UARemoteDataURLKey = @"remote_data_url";
static NSString * const UADeviceAPIURLKey = @"device_api_url";
static NSString * const UAAnalyticsURLKey = @"analytics_api_url";

@implementation UARemoteConfig

- (instancetype)initWithRemoteDataURL:(NSString *)remoteDataURL
                         deviceAPIURL:(NSString *)deviceAPIURL
                         analyticsURL:(NSString *)analyticsURL {
  
    self = [super init];
 
    if (self) {
        self.remoteDataURL = remoteDataURL;
        self.deviceAPIURL = deviceAPIURL;
        self.analyticsURL = analyticsURL;
    }
   
    return self;
}

+ (instancetype)configWithRemoteDataURL:(NSString *)remoteDataURL
                           deviceAPIURL:(NSString *)deviceAPIURL
                           analyticsURL:(NSString *)analyticsURL {
    
    return [[UARemoteConfig alloc] initWithRemoteDataURL:remoteDataURL deviceAPIURL:deviceAPIURL analyticsURL:analyticsURL];
}

+ (instancetype)configWithRemoteData:(NSDictionary *)remoteConfigData {
    NSString *deviceAPIURL = remoteConfigData[UADeviceAPIURLKey];
    NSString *remoteDataURL = remoteConfigData[UARemoteDataURLKey];
    NSString *analyticsURL = remoteConfigData[UAAnalyticsURLKey];
    
    return [UARemoteConfig configWithRemoteDataURL:remoteDataURL deviceAPIURL:deviceAPIURL analyticsURL:analyticsURL];
}

@end
