
#import <Foundation/Foundation.h>

/**
 * Represents the result of performing a background fetch, or none if no fetch was performed.
 */
typedef enum  {
    UAActionFetchResultNone,
    /**
     * The action did not result in any new data being fetched.
     */
    UAActionFetchResultNoData,
    /**
     * The action resulted in new data being fetched.
     */
    UAActionFetchResultNewData,
    /**
     * The action failed.
     */
    UAActionFetchResultFailed,
} UAActionFetchResult;


@interface UAActionResult : NSObject

@property(nonatomic, strong) id value;
@property(nonatomic, assign) UAActionFetchResult fetchResult;


+ (instancetype)resultWithValue:(id)value;

+ (instancetype)resultWithValue:(id)result withFetchResult:(UAActionFetchResult)fetchResult;

+ (instancetype)none;

@end
