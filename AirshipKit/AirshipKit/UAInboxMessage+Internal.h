/* Copyright 2017 Urban Airship and Contributors */

#import "UAInboxMessage.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAInboxMessageData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInboxMessage ()

@property (nonatomic, strong) UAInboxMessageData *data;
@property (nonatomic, weak) UAInboxMessageList *inbox;

+ (instancetype)messageWithData:(UAInboxMessageData *)data;

@end

NS_ASSUME_NONNULL_END
