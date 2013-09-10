
#import <Foundation/Foundation.h>
#import "UAAction.h"
#import "UAActionArguments.h"

@interface UAActionResult : NSObject

@property(nonatomic, strong) id result;
@property(nonatomic, strong) UAActionArguments *arguments;
@property(nonatomic, assign) UAActionFetchResult fetchResult;


+ (instancetype)resultWithObject:(id)result
                   withArguments:(UAActionArguments *)arguments;

+ (instancetype)resultWithObject:(id)result
                   withArguments:arguments
                 withFetchResult:(UAActionFetchResult)fetchResult;

@end
