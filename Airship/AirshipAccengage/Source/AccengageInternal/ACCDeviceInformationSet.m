/* Copyright Airship and Contributors */

#import "ACCDeviceInformationSet+Internal.h"

#if __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#elif __has_include("Airship-Swift.h")
#import "Airship-Swift.h"
#else
@import AirshipCore;
#endif

@interface ACCDeviceInformationSet()
@property (nonatomic, strong) UAAttributesEditor *editor;
@end

@implementation ACCDeviceInformationSet

- (instancetype)init {
    self.editor = [[UAirship channel] editAttributes];
    return self;
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super init];
    return self;
}

- (void)setString:(nonnull NSString *)string forKey:(nonnull NSString *)key {
    [self.editor setString:string attribute:key];
}

- (void)setNumber:(nonnull NSNumber *)number forKey:(nonnull NSString *)key {
    [self.editor setNumber:number attribute:key];
}

- (void)setDate:(NSDate *)date forKey:(NSString *)key {
    [self.editor setDate:date attribute:key];
}

- (void)applyEdits {
    [self.editor apply];
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
