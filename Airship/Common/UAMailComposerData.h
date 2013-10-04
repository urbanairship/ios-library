
#import <Foundation/Foundation.h>

@interface UAMailComposerData : NSObject

@property(nonatomic, strong) NSArray *recipients;
@property(nonatomic, copy) NSString *subject;
@property(nonatomic, copy) NSString *body;

@end
