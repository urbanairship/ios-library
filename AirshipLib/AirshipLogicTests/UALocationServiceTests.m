

#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAStandardLocationService.h"

@interface UALocationServiceTests : SenTestCase {
    id <UALocationService> locationService_;
}
@property (nonatomic, retain) id <UALocationService> locationService;
@end

@implementation UALocationServiceTests
@synthesize locationService = locationService_;
- (void)tearDown {
    if (locationService_) RELEASE(locationService_);
}

- (void) testStandardLocationService {
    
    self.locationService = [[UAStandardLocationService alloc] init];
    STAssertNotNil(locationService_, nil);
    
}



@end