
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

- (void)sendSuccess {
    [self connectionDidFinishLoading:self.urlConnection];
}

- (void)sendFailure {
    [self connection:self.urlConnection didFailWithError:[NSError errorWithDomain:@"whatever" code:0 userInfo:nil]];
}

- (BOOL)startWithoutIO {
    //we need to retain ourselves here, since the failure selector below releases
    [self retain];
    if (_succeed) {
        [self sendSuccess];
    } else {
        [self sendFailure];
    }
    return YES;
}

@end
