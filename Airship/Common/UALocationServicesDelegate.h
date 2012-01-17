//
//  UALocationServicesDelegate.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol UALocationServicesDelegate <NSObject>
@optional
/** Delegate is called when a UALocationServices object reports an error */
- (void)uaLocationManager:(id)UALocationServiceObject 
          locationManager:(CLLocationManager*)locationManager 
         didFailWithError:(NSError*)error;
@end