//
//  UAActionAggregatedResult.h
//  AirshipLib
//
//  Created by Ryan Lepinski on 9/10/13.
//
//

#import <Foundation/Foundation.h>
#import "UAActionResult.h"

@interface UAActionAggregatedResult : UAActionResult
- (void) addResult:(UAActionResult *)result;
@end
