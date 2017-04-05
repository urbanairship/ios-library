/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface UAEventData : NSManagedObject

@property (nullable, nonatomic, retain) NSString *sessionID;
@property (nullable, nonatomic, retain) NSData *data;
@property (nullable, nonatomic, retain) NSString *time;
@property (nullable, nonatomic, retain) NSNumber *bytes;
@property (nullable, nonatomic, retain) NSString *type;
@property (nullable, nonatomic, retain) NSString *identifier;
@property (nullable, nonatomic, retain) NSDate *storeDate;


@end
