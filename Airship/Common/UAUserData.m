
#import "UAUserData.h"

@interface UAUserData()

@property(nonatomic, copy) NSString *username;
@property(nonatomic, copy) NSString *password;
@property(nonatomic, copy) NSString *url;

@end

@implementation UAUserData

- (id)initWithUsername:(NSString *)username password:(NSString *)password url:(NSString *)url {
    self = [super init];
    if (self) {
        self.username = username;
        self.password = password;
        self.url = url;
    }

    return self;
}

+ (id)dataWithUsername:(NSString *)username password:(NSString *)password url:(NSString *)url {
    return [[[UAUserData alloc] initWithUsername:username password:password url:url] autorelease];
}

- (void)dealloc {
    self.username = nil;
    self.password = nil;
    self.url = nil;
    [super dealloc];
}

@end
