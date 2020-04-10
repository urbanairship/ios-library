/* Copyright Airship and Contributors */

#import "ACCDeviceInformationSet+Internal.h"

@implementation ACCDeviceInformationSet

- (instancetype)init {
    self.attributeMutations = [UAAttributeMutations mutations];
    return self;
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)setString:(nonnull NSString *)string forKey:(nonnull NSString *)key {
    [self.attributeMutations setString:string forAttribute:key];
}

- (void)setNumber:(nonnull NSNumber *)number forKey:(nonnull NSString *)key {
    [self.attributeMutations setNumber:number forAttribute:key];
}

- (void)setDate:(NSDate *)date forKey:(NSString *)key {
    [self.attributeMutations setDate:date forAttribute:key];
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    
}

@end
