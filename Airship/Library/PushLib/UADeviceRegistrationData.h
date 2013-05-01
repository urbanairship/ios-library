
#import <Foundation/Foundation.h>

/**
 * Model object encapsulating the data relevant to a registration or unregistration processed by UADeviceAPIClient.
 */
@interface UADeviceRegistrationData : NSObject

/**
 * UADeviceRegistrationData initializer.
 *
 * @param token A device token string.
 * @param payload An NSDictionary representing the payload to be sent in the request body.
 * @param pushEnabled A BOOL indicating whether push is currently enabled.
 */
- (id)initWithDeviceToken:(NSString *)token withPayload:(NSDictionary *)payload pushEnabled:(BOOL)enabled;

/**
 * The device token.
 */
@property(nonatomic, copy, readonly) NSString *deviceToken;
/**
 * The request payload as an NSDictionary.
 */
@property(nonatomic, retain, readonly) NSDictionary *payload;
/**
 * Indicates whether push was enabled at the time the object was constructed.
 */
@property(nonatomic, assign, readonly) BOOL pushEnabled;

@end
