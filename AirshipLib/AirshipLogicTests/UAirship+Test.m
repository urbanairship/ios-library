
#import "UAirship+Test.h"
#import "UAirship.h"

static id mockAirship = nil;

@implementation UAirship (Test)

+ (void)configure:(id)instance {
    mockAirship = instance;
}

+ (void)reset {
    mockAirship = nil;
}

+ (id)shared {
    return mockAirship;
}

@end
