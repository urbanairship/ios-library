/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "ACCDeviceInformationSet.h"

NS_ASSUME_NONNULL_BEGIN

@interface ACCUserProfile : NSObject

///-----------------------------------------------------------------------------
/// @name Update device information
///-----------------------------------------------------------------------------

/*!
 *  @brief Update device information
 *
 *  @param deviceInformation A @c ACCDeviceInformationSet object containing all information to update
 *
 *  @see ACCDeviceInformationSet
 */

- (void)updateDeviceInformation:(ACCDeviceInformationSet *)deviceInformation withCompletionHandler:(nullable void(^)(NSError *__nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
