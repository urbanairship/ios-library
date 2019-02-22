/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroups+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a response from the tag groups lookup API.
 */
@interface UATagGroupsLookupResponse : NSObject <NSCoding>

/**
 * UATagGroupsLookupResponse class factory method.
 *
 * @param tags The tag groups, which may be nil, in case of a failed lookup.
 * @param status The response status.
 * @param lastModifiedTimestamp The last modified timestamp returned in the response, which may be nil in
 * case of a failed lookup.
 */
+ (instancetype)responseWithTagGroups:(nullable UATagGroups *)tags
                               status:(NSUInteger)status
                lastModifiedTimestamp:(nullable NSString *)lastModifiedTimestamp;

/**
 * UATagGroupsLookupResponse class factory method.
 *
 * @param json A JSON payload, or nil in the case of a failed lookup.
 * @param status The response status.
 */
+ (instancetype)responseWithJSON:(nullable NSDictionary *)json status:(NSUInteger)status;

/**
 * The tag groups.
 */
@property(nonatomic, readonly) UATagGroups *tagGroups;

/**
 * The last modified timestamp.
 */
@property(nonatomic, readonly) NSString *lastModifiedTimestamp;

/**
 * The status.
 */
@property(nonatomic, readonly) NSUInteger status;

@end

NS_ASSUME_NONNULL_END
