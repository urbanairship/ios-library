//
//  UADBErrorHandler.m
//  NikeFootball
//
//  Created by Monish Syed on 3/18/15.
//  Copyright (c) 2015 Nike, Inc. All rights reserved.
//

#import "UADBMigrationErrorHandler.h"
#import "UAURLProtocol.h"

@implementation UADBMigrationErrorHandler

+ (void)clearCacheAfterMigrationError {
  [UAURLProtocol clearCache];
}

@end
