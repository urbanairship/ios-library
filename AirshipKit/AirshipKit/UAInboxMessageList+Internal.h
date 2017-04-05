/* Copyright 2017 Urban Airship and Contributors */

#import "UAInboxMessageList.h"
#import "UAInboxAPIClient+Internal.h"

@class UAInboxDBManager;

NS_ASSUME_NONNULL_BEGIN

@interface UAInboxMessageList ()

@property (nonatomic, strong) UAInboxAPIClient *client;
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAInboxDBManager *inboxDBManager;

@property (atomic, assign) NSUInteger batchOperationCount;
@property (atomic, assign) NSUInteger retrieveOperationCount;
@property (nonatomic, strong) NSArray<UAInboxMessage *> *messages;
@property (nonatomic, strong) NSDictionary *messageIDMap;
@property (nonatomic, strong) NSDictionary *messageURLMap;

/**
 * Loads the inbox with the current saved messages.
 */
- (void)loadSavedMessages;

+ (instancetype)messageListWithUser:(UAUser *)user
                             client:(UAInboxAPIClient *)client
                             config:(UAConfig *)config;

@end

NS_ASSUME_NONNULL_END
