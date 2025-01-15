/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeViewModel : NSObject

@property (nonatomic, assign) BOOL pushEnabled;
@property (nonatomic, strong, nullable) NSString *channelID;

- (void)copyChannel;
- (void)togglePushEnabled;

@end

NS_ASSUME_NONNULL_END
