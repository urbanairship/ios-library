
#import "UAHTTPConnection.h"

#pragma mark -
#pragma mark UAHTTPRequest Continuation

@interface UAHTTPRequest()

@property (nonatomic, retain) NSHTTPURLResponse *response;
@property (nonatomic, retain) NSData *responseData;
@property (nonatomic, retain) NSError *error;
@property (nonatomic, retain) NSURL *url;
@end

#pragma mark -
#pragma mark UAHTTPConnection Continuation

@interface UAHTTPConnection()

@property (nonatomic, retain) UAHTTPRequest *request;
@property (nonatomic, retain) NSHTTPURLResponse *urlResponse;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSURLConnection *urlConnection;

- (NSData *)gzipCompress:(NSData *)uncompressedData;

@end
