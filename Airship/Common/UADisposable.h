
#import <Foundation/Foundation.h>

typedef void (^UADisposalBlock)(void);

@interface UADisposable : NSObject

+ (instancetype) disposableWithBlock:(UADisposalBlock)disposalBlock;

- (void)dispose;

@end
