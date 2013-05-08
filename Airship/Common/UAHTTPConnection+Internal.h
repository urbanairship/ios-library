
#import "UAHTTPConnection.h"

#pragma mark -
#pragma mark UAHTTPRequest Continuation

@interface UAHTTPRequest()

@property (retain, nonatomic) NSHTTPURLResponse *response;
@property (retain, nonatomic) NSData *responseData;
@property (retain, nonatomic) NSError *error;

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
