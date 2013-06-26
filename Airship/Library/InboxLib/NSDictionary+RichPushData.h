
#import <Foundation/Foundation.h>

typedef void (^UAInboxMessageIDBlock)(NSString *messageID);

/**
 * Helper category extensions for parsing Rich Push data from notification dictionaries.
 */
@interface NSDictionary(RichPushData)

/**
 *  Retrieves a rich push message ID from a notification dictionary, executing
 *  The supplied block with the ID as an argument if it is found.
 */
- (void)getRichPushMessageIDWithAction:(UAInboxMessageIDBlock)actionBlock;

@end
