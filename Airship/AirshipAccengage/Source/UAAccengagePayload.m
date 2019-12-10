/* Copyright Airship and Contributors */

#import "UAAccengagePayload.h"

static NSString * const UAAccengageIDKey = @"a4sid";
static NSString * const UAAccengageURLKey = @"a4surl";
static NSString * const UAAccengageExternalActionKey = @"openWithSafari";
static NSString * const UAAccengageButtonListKey = @"a4sb";
static NSString * const UAAccengageActionKey = @"action";
static NSString * const UAAccengageButtonURLKey = @"url";
static NSString * const UAAccengageButtonIDKey = @"bid";
NSString * const UAAccengageButtonWebviewAction = @"webView";
NSString * const UAAccengageButtonBrowserAction = @"browser";

@interface UAAccengagePayload()

@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *url;
@property (nonatomic, assign, readwrite, getter=hasExternalURLAction) BOOL externalURLAction;
@property (nonatomic, copy, readwrite) NSArray *buttons;

@end

@interface UAAccengageButton()

@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *url;
@property (nonatomic, copy, readwrite) NSString *actionType;

@end

@implementation UAAccengagePayload

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];

    if (self) {
        NSDictionary *payload = dictionary;
       
        id idValue = payload[UAAccengageIDKey];
        if (![self validateIdentifier:idValue]) {
            return nil;
        }
        self.identifier = idValue;
        
        id urlValue = payload[UAAccengageURLKey];
        if ([self validateURL:urlValue]) {
            self.url = urlValue;
        }
        
        id externalURLActionValue = payload[UAAccengageExternalActionKey];
        if ([self validateExternalURLAction:externalURLActionValue]) {
            self.externalURLAction = [externalURLActionValue boolValue];
        }
        
        id buttonList = payload[UAAccengageButtonListKey];
        if ([self validateButtonList:buttonList]) {
            NSMutableArray *buttons = [NSMutableArray array];
            
            for (id object in buttonList) {
                UAAccengageButton *button = [UAAccengageButton buttonWithJSONObject:object];
                if (button) {
                    [buttons addObject:button];
                }
            }
            
            self.buttons = buttons.copy;
        }
    }
    
    return self;
}

+ (instancetype)payloadWithDictionary:(NSDictionary *)dictionary {
    return [[self alloc] initWithDictionary:dictionary];
}

- (BOOL)validateIdentifier:(id)identifier {
    return [identifier isKindOfClass:[NSString class]];
}

- (BOOL)validateURL:(id)url {
    return [url isKindOfClass:[NSString class]];
}

- (BOOL)validateExternalURLAction:(id)action {
    return [action isKindOfClass:[NSNumber class]];
}

- (BOOL)validateButtonList:(id)list {
    return [list isKindOfClass:[NSArray class]];
}

@end

@implementation UAAccengageButton

- (instancetype)initWithJSONObject:(id)object {
    self = [super init];

    if (self) {
        NSDictionary *payload = object;
      
        id buttonIDValue = payload[UAAccengageButtonIDKey];
        if (![self validateIdentifier:buttonIDValue]) {
            return nil;
        }
        self.identifier = buttonIDValue;
        
        id urlValue = payload[UAAccengageButtonURLKey];
        if (![self validateURL:urlValue]) {
            return nil;
        }
        self.url = urlValue;
        
        id actionValue = payload[UAAccengageActionKey];
        if ([self validateActionType:actionValue]) {
            self.actionType = actionValue;
        }
    }
    
    return self;
}

+ (instancetype)buttonWithJSONObject:(id)object {
    return [[self alloc] initWithJSONObject:object];
}

- (BOOL)validateIdentifier:(id)identifier {
    return [identifier isKindOfClass:[NSString class]];
}

- (BOOL)validateURL:(id)url {
    return [url isKindOfClass:[NSString class]];
}

- (BOOL)validateActionType:(id)actionType {
    return [actionType isKindOfClass:[NSString class]];
}

@end
