
static BOOL _succeed = YES;

#import "UAHTTPConnection+Test.h"
#import "JRSwizzle.h"

@implementation UAHTTPConnection (Test)

+ (void)succeed {
    _succeed = YES;
}

+ (void)fail {
    _succeed = NO;
}

+ (void)swizzle {
    [self jr_swizzleMethod:@selector(start) withMethod:@selector(startWithoutIO) error:nil];
}

+ (void)unSwizzle {
    [self jr_swizzleMethod:@selector(startWithoutIO) withMethod:@selector(start) error:nil];
}

- (void)sendResponse:(void (^)(void))block{
    if (self.delegateQueue) {
        [[NSOperationQueue mainQueue] addOperation:[NSBlockOperation blockOperationWithBlock:block]];
    } else {
        block();
    }
}

- (void)sendSuccess {
    [self sendResponse:^{
        [self connectionDidFinishLoading:self.urlConnection];
    }];
}

- (void)sendFailure {
    [self sendResponse:^{
        [self connection:self.urlConnection didFailWithError:[NSError errorWithDomain:@"whatever" code:0 userInfo:nil]];
    }];
}

- (BOOL)startWithoutIO {
    if (_succeed) {
        [self sendSuccess];
    } else {
        [self sendFailure];
    }
    return YES;
}

@end
