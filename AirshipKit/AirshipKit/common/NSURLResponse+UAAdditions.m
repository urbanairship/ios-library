
#import "NSURLResponse+UAAdditions.h"

@implementation NSURLResponse (UAAdditions)

- (BOOL)hasRetriableStatus {
    if ([self isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)self;
        BOOL serverError = response.statusCode >= 500 && response.statusCode <= 599;
        BOOL tooManyRequests = response.statusCode == 429;

        if (serverError || tooManyRequests) {
            return YES;
        }
    }

    return NO;
}

@end
