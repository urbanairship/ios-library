/* Copyright Airship and Contributors */

#import "UALegacyLoggingBridge.h"


@implementation UALegacyLoggingBridge

static UALoggerBlock _loggerBlock = nil;

+ (void)setLogger:(UALoggerBlock)loggerBlock {
    _loggerBlock = loggerBlock;
}

+ (UALoggerBlock)logger {
    return _loggerBlock;
}

+ (void)logWithLevel:(NSInteger)level
              fileID:(NSString *)fileID
            function:(NSString *)function
                line:(NSUInteger)line
             message:(UAMessageBlock)messageBlock {

    UALoggerBlock loggerBlock = _loggerBlock;
    if (loggerBlock) {
        loggerBlock(level, fileID, function, line, messageBlock);
    }
}

@end
