
#import "UAInboxMessageList.h"
#import "UAInboxAPIClient.h"

@class UAInboxDBManager;

@interface UAInboxMessageList ()

@property (nonatomic, strong) UAInboxAPIClient *client;
@property (nonatomic, strong) UAUser *user;
@property (nonatomic, strong) UAInboxDBManager *inboxDBManager;

@property (atomic, assign) NSUInteger batchOperationCount;
@property (atomic, assign) NSUInteger retrieveOperationCount;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) NSDictionary *messageIDMap;
@property (nonatomic, strong) NSDictionary *messageURLMap;

/**
 * Loads the inbox with the current saved messages.
 */
- (void)loadSavedMessages;


+ (instancetype)messageListWithUser:(UAUser *)user client:(UAInboxAPIClient *)client config:(UAConfig *)config;

@end
