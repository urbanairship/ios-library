
#import <Foundation/Foundation.h>

@interface UAUserData : NSObject

+ (id)dataWithUsername:(NSString *)username password:(NSString *)password url:(NSString *)url;
- (id)initWithUsername:(NSString *)username password:(NSString *)password url:(NSString *)url;

@property(nonatomic, readonly, copy) NSString *username;
@property(nonatomic, readonly, copy) NSString *password;
@property(nonatomic, readonly, copy) NSString *url;

@end
