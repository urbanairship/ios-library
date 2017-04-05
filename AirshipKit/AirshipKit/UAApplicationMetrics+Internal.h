/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAApplicationMetrics.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAApplicationMetrics ()


@property (nonatomic, strong, nullable) NSDate *lastApplicationOpenDate;

- (void)didBecomeActive;

@end

NS_ASSUME_NONNULL_END
