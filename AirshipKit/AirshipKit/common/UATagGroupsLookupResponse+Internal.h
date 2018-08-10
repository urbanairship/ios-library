/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroups+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UATagGroupsLookupResponse : NSObject <NSCoding>

+ (instancetype)responseWithTagGroups:(nullable UATagGroups *)tags
                               status:(NSUInteger)status
                lastModifiedTimestamp:(nullable NSString *)lastModifiedTimestamp;

+ (instancetype)responseWithJSON:(nullable NSDictionary *)json status:(NSUInteger)status;

@property(nonatomic, readonly) UATagGroups *tagGroups;
@property(nonatomic, readonly) NSString *lastModifiedTimestamp;
@property(nonatomic, readonly) NSUInteger status;

@end

NS_ASSUME_NONNULL_END
