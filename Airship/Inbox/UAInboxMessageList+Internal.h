
#import "UAInboxMessageList.h"
#import "UAInboxAPIClient.h"

@interface UAInboxMessageList ()

@property (nonatomic, strong) UAInboxAPIClient *client;
@property (atomic, assign) NSUInteger batchOperationCount;
@property (atomic, assign) NSUInteger retrieveOperationCount;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSArray *messages;

/**
 * Loads the inbox with the current saved messages.
 */
- (void)loadSavedMessages;

@end
