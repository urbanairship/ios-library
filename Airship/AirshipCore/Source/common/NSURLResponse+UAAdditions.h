
#import <Foundation/Foundation.h>

@interface NSURLResponse (UAAdditions)

/**
 * Whether the response indicates that a retry is necessary or feasible.
 * @return `YES` if the operation should be retried, otherwise `NO`.
 */
- (BOOL)hasRetriableStatus;

@end
