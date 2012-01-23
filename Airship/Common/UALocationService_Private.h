//
//  UALocationService_Private.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/23/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UALocationService.h"
#import "UABaseLocationDelegate.h"

@interface UALocationService ()
- (void)setDistanceFilterAndDesiredLocation:(UABaseLocationDelegate*)locationDelegate;
@property (nonatomic, retain) UAStandardLocationDelegate *standardLocationDelegate;
@property (nonatomic, assign) UALocationServiceStatus standardLocationServiceStatus;
@property (nonatomic, retain) UASignificantChangeDelegate *significantChangeDelegate;
@property (nonatomic, assign) UALocationServiceStatus significantChangeServiceStatus;
@end
