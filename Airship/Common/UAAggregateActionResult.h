#import <Foundation/Foundation.h>
#import "UAActionResult.h"

@interface UAAggregateActionResult : UAActionResult
- (void) addResult:(UAActionResult *)result forAction:(NSString *)actionName;
@end