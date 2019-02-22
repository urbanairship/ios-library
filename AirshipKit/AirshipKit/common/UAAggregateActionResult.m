/* Copyright Urban Airship and Contributors */

#import "UAAggregateActionResult.h"
#import "UAActionResult+Internal.h"

@implementation UAAggregateActionResult

- (instancetype)init {

    self = [super init];
    if (self) {
        self.value = [NSMutableDictionary dictionary];
        self.fetchResult = UAActionFetchResultNoData;
    }

    return self;
}

- (void)addResult:(UAActionResult *)result forAction:(NSString*)actionName {
    @synchronized(self) {
        [self.value setValue:result forKey:actionName];
        [self mergeFetchResult:result.fetchResult];
    }
}

- (UAActionResult *)resultForAction:(NSString*)actionName {
    return [self.value valueForKey:actionName];
}

- (void)mergeFetchResult:(UAActionFetchResult)result {
    if (self.fetchResult == UAActionFetchResultNewData || result == UAActionFetchResultNewData) {
        self.fetchResult = UAActionFetchResultNewData;
    } else if (self.fetchResult == UAActionFetchResultFailed || result == UAActionFetchResultFailed) {
        self.fetchResult = UAActionFetchResultFailed;
    }
}

@end
