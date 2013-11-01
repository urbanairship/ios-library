
#import "UAInternalJSDelegate.h"
#import "UAGlobal.h"

@implementation UAInternalJSDelegate

- (NSString *)callbackArguments:(NSArray *)args withOptions:(NSDictionary *)options {
    UA_LDEBUG(@"JS default delegate arguments: %@ \n options: %@", args, options);

    BOOL hasError = NO;

    // do something with the args and options, set error if necessary
    // ...

    // invoke JS callback w/ result
    NSString *script = nil;
    if (!hasError) {
        script = @"UAListener.result = 'Callback from ObjC succeeded'; UAListener.onSuccess();";
    } else {
        script = @"UAListener.error = 'Callback from ObjC failed'; UAListener.onError();";
    }
    return script;
}

@end
