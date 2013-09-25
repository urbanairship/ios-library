
#import "UAActionResult.h"

@implementation UAActionResult

- (instancetype)initWithValue:(id)value
               withFetchResult:(UAActionFetchResult)fetchResult {

    self = [super init];
    if (self) {
        self.value = value;
        self.fetchResult = fetchResult;
    }

    return self;
}

+ (instancetype)resultWithValue:(id)value {

    return [[UAActionResult alloc] initWithValue:value
                                  withFetchResult:UAActionFetchResultNoData];

}

+ (instancetype)resultWithValue:(id)value
                 withFetchResult:(UAActionFetchResult)fetchResult {

    return [[UAActionResult alloc] initWithValue:value
                                  withFetchResult:fetchResult];
}

+ (instancetype)none {
    return [[UAActionResult alloc] initWithValue:nil withFetchResult:UAActionFetchResultNoData];
}


@end
