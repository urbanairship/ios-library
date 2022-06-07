/* Copyright Airship and Contributors */

#import "UALegacyLoggingBridge.h"


@implementation UALegacyLoggingBridge

static LoggerBlock _loggerBlock = nil;

+ (void)setLogger:(LoggerBlock)loggerBlock {
    _loggerBlock = loggerBlock;
}

+ (LoggerBlock)logger {
    return _loggerBlock;
}

+ (void)logWithLevel:(NSInteger)level
              fileID:(NSString *)fileID
            function:(NSString *)function
                line:(NSUInteger)line
             message:(NSString *)message {

    LoggerBlock loggerBlock = _loggerBlock;
    if (loggerBlock) {
        loggerBlock(level, message, fileID, function, line);
    }
}

@end
