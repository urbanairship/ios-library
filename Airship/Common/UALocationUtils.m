//
//  UALocationServices.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

/* Common variables for the UALocationServices classes */

#import "UALocationUtils.h"
#import "UAirship.h" 
#import "UAAnalytics.h" 
#import "UAEvent.h"
#import "UALocationServicesCommon.h"



@implementation UALocationUtils

//TODO: look into optimizing this to avoid the NSNumber throwaway object
//      without losing precision
+ (NSString*)stringFromDouble:(double)doubleValue {
    NSNumber *number = [NSNumber numberWithDouble:doubleValue];
    return [number stringValue];
}


@end

