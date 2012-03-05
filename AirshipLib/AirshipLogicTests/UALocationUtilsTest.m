//
//  AirshipLib - UALocationUtilsTest.m
//  Copyright 2012 Urban Airship. All rights reserved.
//
//  Created by: Matt Hooge
//

#import "UALocationUtils.h"
#import <SenTestingKit/SenTestingKit.h>

@interface UALocationUtilsTest : SenTestCase

@end


@implementation UALocationUtilsTest

- (void)testStringFromDouble {
    double pi = M_PI;
    NSString *stringPi = [UALocationUtils stringFromDouble:pi];
    double piBack = [stringPi doubleValue];
    STAssertEquals(pi, piBack, nil);
}



@end
