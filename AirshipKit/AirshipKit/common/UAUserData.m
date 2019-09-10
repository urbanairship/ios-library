/* Copyright Airship and Contributors */

#import "UAUserData+Internal.h"

@interface UAUserData()

@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;

@end

@implementation UAUserData

- (instancetype)initWithUsername:(NSString *)username password:(NSString *)password {
    self = [super init];
    if (self) {
        self.username = username;
        self.password = password;
    }

    return self;
}

+ (instancetype)dataWithUsername:(NSString *)username password:(NSString *)password {
    return [[self alloc] initWithUsername:username password:password];
}


@end
