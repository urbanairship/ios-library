
#import "UAExampleActions.h"

@implementation YesAction

- (id)performWithArguments:(id)arguments {
    return [NSNumber numberWithBool:YES];
}

@end

@implementation NoAction

- (id)performWithArguments:(id)arguments {
    return [NSNumber numberWithBool:NO];
}

@end

@implementation LogAction

- (id)performWithArguments:(id)arguments {
    NSLog(@"let's log a thing: %@", [arguments description]);
    return nil;
}

@end

@implementation AsyncLogAndReturnStringAction

- (void)performWithArguments:(id)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler {
    NSLog(@"maybe you need to log something after an asynchronous API call? work with me here: %@", [arguments description]);
    completionHandler(@"this is a custom completion value, beetches");
}

@end

