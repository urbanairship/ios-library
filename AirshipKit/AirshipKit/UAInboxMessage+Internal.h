/* Copyright 2017 Urban Airship and Contributors */

#import "UAInboxMessage.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAInboxMessageData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UAInboxMessage
 */
@interface UAInboxMessage ()

///---------------------------------------------------------------------------------------
/// @name Message Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The message data.
 */
@property (nonatomic, strong) UAInboxMessageData *data;

/**
 * The message list instance.
 */
@property (nonatomic, weak) UAInboxMessageList *inbox;

///---------------------------------------------------------------------------------------
/// @name Message Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Initializes an inbox message with the data provided.
 *
 * @param data The message data.
 */
+ (instancetype)messageWithData:(UAInboxMessageData *)data;

@end

NS_ASSUME_NONNULL_END
