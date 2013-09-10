//
//  UAActionAggregatedResult.m
//  AirshipLib
//
//  Created by Ryan Lepinski on 9/10/13.
//
//

#import "UAActionAggregatedResult.h"

@implementation UAActionAggregatedResult

- (instancetype)init {

    self = [super init];
    if (self) {
        self.result = [NSMutableDictionary dictionary];
        self.arguments = nil;
        self.fetchResult = UAActionFetchResultNoData;
    }

    return self;
}


- (void) addResult:(UAActionResult *)result {
    NSDictionary *resultDictionary = (NSMutableDictionary *)self.result;
    [resultDictionary setValue:result forKey:result.arguments.name];
    [self mergeFetchResult:result.fetchResult];
}

- (void)mergeFetchResult:(UAActionFetchResult)result {
    if (self.fetchResult == UAActionFetchResultNewData || result == UAActionFetchResultNewData) {
        self.fetchResult = UAActionFetchResultNewData;
    } else if (self.fetchResult == UAActionFetchResultFailed || result == UAActionFetchResultFailed) {
        self.fetchResult = UAActionFetchResultFailed;
    }
}

@end
