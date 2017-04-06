/* Copyright 2017 Urban Airship and Contributors */

#import "UAActionArguments.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAActionArguments ()

@property (nonatomic, readonly) NSString *situationString;
@property (nonatomic, copy, nullable) NSDictionary *metadata;
@property (nonatomic, assign) UASituation situation;
@property (nonatomic, strong, nullable) id value;

@end

NS_ASSUME_NONNULL_END
