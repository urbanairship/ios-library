/* Copyright Airship and Contributors */

#import "UAHTTPRequestOperation+Internal.h"

@interface UAHTTPRequestOperation()
@property (nonatomic, strong) UADisposable *requestDisposable;
@property (nonatomic, strong) UARequestSession *session;
@property (nonatomic, strong) UARequest *request;
@property (nonatomic, copy) UAHTTPRequestCompletionHandler completionHandler;
@end

@implementation UAHTTPRequestOperation

- (instancetype)initWithRequest:(UARequest *)request
                       sesssion:(UARequestSession *)session
              completionHandler:(UAHTTPRequestCompletionHandler)completionHandler {

    self = [super init];
    if (self) {
        self.session = session;
        self.request = request;
        self.completionHandler = completionHandler;
    }
    return self;
}

+ (instancetype)operationWithRequest:(UARequest *)request
                             session:(UARequestSession *)session
                   completionHandler:(UAHTTPRequestCompletionHandler)completionHandler {

    return [[self alloc] initWithRequest:request
                                sesssion:session
                       completionHandler:completionHandler];
}

- (void)startAsyncOperation {
    self.requestDisposable = [self.session performHTTPRequest:self.request completionHandler:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        @synchronized (self) {
            if (!self.isCancelled && self.completionHandler) {
                self.completionHandler(data, response, error);
            }
        }

        [self finish];
    }];
}

- (void)finish {
    @synchronized (self) {
        self.requestDisposable = nil;
        self.completionHandler = nil;
        self.request = nil;
        self.session = nil;
    }

    [super finish];
}

- (void)cancel {
    @synchronized (self) {
        [self.requestDisposable dispose];
    }
    [super cancel];
}

- (void)dealloc {
    [self.requestDisposable dispose];
}

@end

