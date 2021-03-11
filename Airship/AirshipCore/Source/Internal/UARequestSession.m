/* Copyright Airship and Contributors */


#import "UARequestSession.h"
#import "UARuntimeConfig.h"
#import "UAirship.h"

NSString * const UARequestSessionErrorDomain = @"com.urbanairship.request_session";

@interface UARequestSession()
@property(nonatomic, strong) NSURLSession *session;
@property(nonatomic, strong) NSMutableDictionary *headers;
@end

@implementation UARequestSession

- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(NSURLSession *)session {
    self = [super init];

    if (self) {
        self.headers = [NSMutableDictionary dictionary];
        self.session = session;
        [self setValue:@"gzip;q=1.0, compress;q=0.5" forHeader:@"Accept-Encoding"];
        [self setValue:[UARequestSession userAgentWithAppKey:config.appKey] forHeader:@"User-Agent"];
    }

    return self;
}

+ (instancetype)sessionWithConfig:(UARuntimeConfig *)config {
    static dispatch_once_t onceToken;
    static NSURLSession *_session;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];

        // Disable the default HTTP cache so that 304 responses can be received. API clients using
        // UARequestSession are expected to provide their own caching.
        sessionConfig.URLCache = nil;
        sessionConfig.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

        // Force min 1.2 even though our backend will always negotiate 1.2+
        sessionConfig.TLSMinimumSupportedProtocol = kTLSProtocol12;

        _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:nil];
    });

    return [[self alloc] initWithConfig:config session:_session];
}

+ (instancetype)sessionWithConfig:(UARuntimeConfig *)config
                     NSURLSession:(NSURLSession *)session {
    return [[self alloc] initWithConfig:config session:session];
}

- (void)setValue:(id)value forHeader:(NSString *)field {
    [self.headers setValue:value forKey:field];
}

- (UADisposable *)performHTTPRequest:(UARequest *)request
                   completionHandler:(UAHTTPRequestCompletionHandler)completionHandler {

    if (!request.URL.host) {
        [self.session.delegateQueue addOperationWithBlock:^{
            NSString *msg = [NSString stringWithFormat:@"Attempted to perform request with a missing URL."];

            NSError *error = [NSError errorWithDomain:UARequestSessionErrorDomain
                                                 code:UARequestSessionErrorMissingURL
                                             userInfo:@{NSLocalizedDescriptionKey:msg}];
            completionHandler(nil, nil, error);
        }];

        return [[UADisposable alloc] init];
    }
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:request.URL];
    [URLRequest setHTTPShouldHandleCookies:NO];
    [URLRequest setHTTPMethod:request.method];
    [URLRequest setHTTPBody:request.body];

    for (NSString *key in self.headers) {
        [URLRequest setValue:self.headers[key] forHTTPHeaderField:key];
    }

    for (NSString *key in request.headers) {
        [URLRequest setValue:request.headers[key] forHTTPHeaderField:key];
    }

    NSURLSessionTask *task = [self.session dataTaskWithRequest:URLRequest
                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        NSHTTPURLResponse *httpResponse;
        if (!error) {
            httpResponse = [UARequestSession castResponse:response error:&error];
        }

        if (error) {
            completionHandler(nil, nil, error);
        } else {
            completionHandler(data, httpResponse, nil);
        }
    }];

    [task resume];

    return [UADisposable disposableWithBlock:^{
        [task cancel];
    }];
}

+ (NSHTTPURLResponse *)castResponse:(NSURLResponse *)response error:(NSError **)error {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        return (NSHTTPURLResponse *)response;
    }

    if (!*error) {
        NSString *msg = [NSString stringWithFormat:@"Unable to cast to NSHTTPURLResponse: %@", response];

        *error = [NSError errorWithDomain:UARequestSessionErrorDomain
                                     code:UARequestSessionErrorInvalidHTTPResponse
                                 userInfo:@{NSLocalizedDescriptionKey:msg}];
    }

    return nil;
}

+ (NSString *)userAgentWithAppKey:(NSString *)appKey {
    /*
     * [LIB-101] User agent string should be:
     * App 1.0 (iPad; iPhone OS 5.0.1; UALib 1.1.2; <app key>; en_US)
     */

    UIDevice *device = [UIDevice currentDevice];

    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *info = [bundle infoDictionary];

    NSString *appName = [info objectForKey:(NSString*)kCFBundleNameKey];
    NSString *appVersion = [info objectForKey:@"CFBundleShortVersionString"];

    NSString *deviceModel = [device model];
    NSString *osName = [device systemName];
    NSString *osVersion = [device systemVersion];

    NSString *libVersion = [UAirshipVersion get];
    NSString *locale = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];

    return [NSString stringWithFormat:@"%@ %@ (%@; %@ %@; UALib %@; %@; %@)",
            appName, appVersion, deviceModel, osName, osVersion, libVersion, appKey, locale];
}

@end
