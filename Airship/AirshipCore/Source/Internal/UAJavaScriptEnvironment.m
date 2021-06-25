/* Copyright Airship and Contributors */

#import "UAJavaScriptEnvironment.h"
#import "NSString+UAURLEncoding.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAChannel.h"
#import "UANamedUser.h"
#import "UARuntimeConfig.h"


#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@interface UAJavaScriptEnvironment()
@property (nonatomic) NSMutableSet *extensions;
@end

@implementation UAJavaScriptEnvironment

- (instancetype)init {
    self = [super init];
    if (self) {
        self.extensions = [NSMutableSet set];
    }
    return self;
}

+ (instancetype)defaultEnvironment {
    UAJavaScriptEnvironment *environment = [[self alloc] init];
    [environment addStringGetter:@"getDeviceModel" value:[UIDevice currentDevice].model];
    [environment addStringGetter:@"getNamedUser" value:[UAirship namedUser].identifier];
    [environment addStringGetter:@"getChannelId" value:[UAirship channel].identifier];
    [environment addStringGetter:@"getAppKey" value:[UAirship shared].config.appKey];
    return environment;
}

- (void)addNumberGetter:(NSString *)methodName value:(NSNumber *)value {
    NSString *extension = [NSString stringWithFormat:@"_UAirship.%@ = function() {return %@;};", methodName, value ?: @(-1)];
    [self.extensions addObject:extension];
}

- (void)addStringGetter:(NSString *)methodName value:(NSString *)value {
    NSString *extension;
    if (!value) {
        extension = [NSString stringWithFormat:@"_UAirship.%@ = function() {return null;};", methodName];
    } else {
        NSString *encodedValue = [value urlEncodedString];
        extension = [NSString stringWithFormat:@"_UAirship.%@ = function() {return decodeURIComponent(\"%@\");};", methodName, encodedValue];
    }
    [self.extensions addObject:extension];
}

- (void)addDictionaryGetter:(NSString *)methodName value:(NSDictionary *)value {
    NSString *extension;
    
    if (!value || ![NSJSONSerialization isValidJSONObject:value]) {
        extension = [NSString stringWithFormat:@"_UAirship.%@ = function() {return null;};", methodName];
        [self.extensions addObject:extension];
        return;
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
  
    if (error) {
        extension = [NSString stringWithFormat:@"_UAirship.%@ = function() {return null;};", methodName];
        [self.extensions addObject:extension];
        return;
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    extension = [NSString stringWithFormat:@"_UAirship.%@ = function() {return %@;};", methodName, jsonString];
    
    [self.extensions addObject:extension];
}

- (NSString *)build {
    NSString *js = @"var _UAirship = {};";

    for (NSString *extension in self.extensions) {
        js = [js stringByAppendingString:extension];
    }

    NSString *path = [[UAirshipCoreResources bundle] pathForResource:@"UANativeBridge" ofType:@""];
    if (path) {
        NSString *bridge = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (bridge) {
            js = [js stringByAppendingString:bridge];
        } else {
            UA_LIMPERR(@"UANativeBridge resource file is not decodable.");
        }
    } else {
        UA_LIMPERR(@"UANativeBridge resource file is missing.");
    }

    return js;
}

@end
