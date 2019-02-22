/* Copyright Urban Airship and Contributors */

#import "UARemoteDataPayload+Internal.h"
#import "UAUtils+Internal.h"

@implementation UARemoteDataPayload

- (instancetype)initWithType:(NSString *)type timestamp:(NSDate *)timestamp data:(NSDictionary *)data {
    self = [super init];
    if (self) {
        self.type = type;
        self.timestamp = timestamp;
        self.data = data;
    }
    return self;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }
    
    return [self isEqualToRemoteData:(UARemoteDataPayload *)other];
}

- (BOOL)isEqualToRemoteData:(UARemoteDataPayload *)other {
    if (!other) return NO;
    
    if (![self.type isEqualToString:other.type]) {
         return NO;
    }
    if (![self.timestamp isEqualToDate:other.timestamp]) {
        return NO;
    }
    if (![self.data isEqualToDictionary:other.data]) {
        return NO;
    }
    
    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.type hash];
    result = 31 * result + [self.timestamp hash];
    result = 31 * result + [self.data hash];
    return result;
}

- (id)copyWithZone:(NSZone *)zone {
    UARemoteDataPayload *copy = [[UARemoteDataPayload allocWithZone:zone] init];
    
    copy.type = [self.type copy];
    copy.timestamp = [self.timestamp copy];
    copy.data = [self.data copy];
    
    return copy;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"type = %@, timestamp = %@, data = %@", self.type, self.timestamp, self.data];
}

NSString * const UARemoteDataTypeKey = @"type";
NSString * const UARemoteDataTimestampKey = @"timestamp";
NSString * const UARemoteDataDataKey = @"data";

+ (NSArray<UARemoteDataPayload *> *)remoteDataPayloadsFromJSON:(NSArray *)remoteDataPayloadsAsJSON {
    NSMutableArray<UARemoteDataPayload *> *remoteDataPayloads = [NSMutableArray array];
    for (NSDictionary *remoteDataPayloadAsJSON in remoteDataPayloadsAsJSON) {
        UARemoteDataPayload *remoteDataPayload = [UARemoteDataPayload remoteDataPayloadFromJSON:remoteDataPayloadAsJSON];
        
        // Add the UARemoteDataPayload object to the array we will return
        if (remoteDataPayload) {
            [remoteDataPayloads addObject:remoteDataPayload];
        }
    }
    return remoteDataPayloads;
}

+ (UARemoteDataPayload *)remoteDataPayloadFromJSON:(NSDictionary *)remoteDataPayloadAsJSON {
    // parse the JSON
    id type = remoteDataPayloadAsJSON[UARemoteDataTypeKey];
    if (!([type isKindOfClass:[NSString class]] && ([type length] > 0))) {
        return nil;
    }
    NSString *payloadType = type;
    
    id timestamp = remoteDataPayloadAsJSON[UARemoteDataTimestampKey];
    if (!([timestamp isKindOfClass:[NSString class]] && ([timestamp length] > 0))) {
        return nil;
    }
    NSDate *payloadTimestamp = [UAUtils parseISO8601DateFromString:timestamp];
    if (!payloadTimestamp) {
        return nil;
    }
    
    id data = remoteDataPayloadAsJSON[UARemoteDataDataKey];
    if (!([data isKindOfClass:[NSDictionary class]])) {
        return nil;
    }
    NSDictionary *payloadData = data;
    
    // create a UARemoteDataPayload object from the parsed json
    UARemoteDataPayload *remoteDataPayload = [[UARemoteDataPayload alloc] initWithType:payloadType timestamp:payloadTimestamp data:payloadData];
    
    return remoteDataPayload;
}

@end
