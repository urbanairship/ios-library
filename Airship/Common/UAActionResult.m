
#import "UAActionResult.h"

@implementation UAActionResult


- (instancetype)initWithObject:(id)result
                 withArguments:arguments
               withFetchResult:(UAActionFetchResult)fetchResult {

    self = [super init];
    if (self) {
        self.result = result;
        self.arguments = arguments;
        self.fetchResult = fetchResult;
    }

    return self;
}

+ (instancetype)resultWithObject:(id)result
                   withArguments:(UAActionArguments *)arguments {

    return [[UAActionResult alloc] initWithObject:result
                                    withArguments:arguments
                                  withFetchResult:UAActionFetchResultNoData];

}

+ (instancetype)resultWithObject:(id)result
                   withArguments:arguments
                 withFetchResult:(UAActionFetchResult)fetchResult {

    return [[UAActionResult alloc] initWithObject:result
                                    withArguments:arguments
                                  withFetchResult:fetchResult];
}


@end
