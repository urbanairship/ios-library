
#import <Foundation/Foundation.h>
#import "UAPreferenceDataStore+Internal.h"
#import "UATagGroupsLookupResponse+Internal.h"

@interface UATagGroupsLookupResponseCache : NSObject

@property (nonatomic, strong) UATagGroupsLookupResponse *response;
@property (nonatomic, strong) UATagGroups *requestedTagGroups;
@property (nonatomic, readonly) NSDate *creationDate;
@property (nonatomic, assign) NSTimeInterval maxAgeTime;
@property (nonatomic, assign) NSTimeInterval staleReadTime;

+ (instancetype)cacheWithDataStore:(UAPreferenceDataStore *)dataStore;

- (BOOL)needsRefresh;
- (BOOL)isStale;

@end
