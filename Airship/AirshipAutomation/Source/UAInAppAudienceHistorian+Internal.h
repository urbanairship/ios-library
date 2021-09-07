/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAirshipAutomationCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

@class UADate;
@protocol UAContactProtocol;
@class UATagGroupUpdate;
@class UAAttributeUpdate;
@class UAChannel;

@interface UAInAppAudienceHistorian : NSObject

/**
* UAInAppAudienceHistorian initializer.
*
* @param channel The channel.
* @param contact The contact.
* @return The initialized historian.
*/
+ (instancetype)historianWithChannel:(UAChannel *)channel
                             contact:(id<UAContactProtocol>)contact;


/**
* UAInAppAudienceHistorian initializer.
*
* @param channel The channel.
* @param contact The contact.
 @param date The date.
* @return The initialized historian.
*/
+ (instancetype)historianWithChannel:(UAChannel *)channel
                             contact:(id<UAContactProtocol>)contact
                                date:(UADate *)date;

/**
 * Gets tag history newer than the provided date.
 * @param date The date.
 * @return An array of tag updates.
 */
- (NSArray<UATagGroupUpdate *> *)tagHistoryNewerThan:(NSDate *)date;

/**
 * Gets attribute history newer than the provided date.
 * @param date The date.
 * @return An array of attribute updates.
 */
- (NSArray<UAAttributeUpdate *> *)attributeHistoryNewerThan:(NSDate *)date;

@end

NS_ASSUME_NONNULL_END
