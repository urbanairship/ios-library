/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UANotificationCategories.h"
#import "UAGlobal.h"
#import "NSString+UALocalizationAdditions.h"
#import "UAirship.h"
#import "UANotificationCategory.h"
#import "UANotificationAction.h"

@implementation UANotificationCategories

+ (NSSet *)defaultCategories {
    return [self defaultCategoriesWithRequireAuth:YES];
}

+ (NSSet *)defaultCategoriesWithRequireAuth:(BOOL)requireAuth {
    if (![UAirship resources]) {
        return [NSSet set];
    }

    return [self createCategoriesFromFile:[[UAirship resources] pathForResource:@"UANotificationCategories" ofType:@"plist"]
                              requireAuth:requireAuth];
}

+ (NSSet *)createCategoriesFromFile:(NSString *)path {
    return [self createCategoriesFromFile:path actionDefinitionModBlock:nil];
}

+ (NSSet *)createCategoriesFromFile:(NSString *)path requireAuth:(BOOL)requireAuth {

    return [self createCategoriesFromFile:path actionDefinitionModBlock:^(NSMutableDictionary *actionDefinition) {
        if (![actionDefinition[@"foreground"] boolValue]) {
            actionDefinition[@"authenticationRequired"] = @(requireAuth);
        }
    }];
}

+ (NSSet *)createCategoriesFromFile:(NSString *)path actionDefinitionModBlock:(void (^)(NSMutableDictionary *))actionDefinitionModBlock {

    NSDictionary *categoriesDictionary = [[NSDictionary alloc] initWithContentsOfFile:path];

    NSMutableSet *categories = [NSMutableSet set];

    for (NSString *categoryId in [categoriesDictionary allKeys]) {
        NSArray *actions = [categoriesDictionary valueForKey:categoryId];
        if (!actions.count) {
            continue;
        }

        if (actionDefinitionModBlock) {
            NSMutableArray *mutableActions = [NSMutableArray arrayWithCapacity:actions.count];

            for (id actionDef in actions) {
                NSMutableDictionary *mutableActionDef = [actionDef mutableCopy];
                actionDefinitionModBlock(mutableActionDef);
                [mutableActions addObject:mutableActionDef];
            }

            actions = mutableActions;
        }

        id category = [self createCategory:categoryId actions:actions];
        if (category) {
            [categories addObject:category];
        }
    }

    return categories;
}

+ (UANotificationCategory *)createCategory:(NSString *)categoryId actions:(NSArray *)actionDefinitions {
    NSMutableArray *actions = [NSMutableArray array];

    for (NSDictionary *actionDefinition in actionDefinitions) {
        NSString *title;
        if (actionDefinition[@"title_resource"]) {
            title = [actionDefinition[@"title_resource"] localizedStringWithTable:@"UrbanAirship"
                                                                     defaultValue:actionDefinition[@"title"]];
        } else if (actionDefinition[@"title"]) {
            title = actionDefinition[@"title"];
        }

        NSString *actionId = actionDefinition[@"identifier"];

        if (!title) {
            UA_LERR(@"Error creating category: %@ for action: %@ due to missing required title.",
                    categoryId, actionId);
            return nil;
        }

        UANotificationActionOptions options = UANotificationActionOptionNone;

        if ([actionDefinition[@"destructive"] boolValue]) {
            options |= UANotificationActionOptionDestructive;
        }

        if ([actionDefinition[@"foreground"] boolValue]) {
            options |= UANotificationActionOptionForeground;
        }

        if ([actionDefinition[@"authenticationRequired"] boolValue]) {
            options |= UANotificationActionOptionAuthenticationRequired;
        }

        UANotificationAction *action = [UANotificationAction actionWithIdentifier:actionId
                                                                            title:title
                                                                          options:options];
        [actions addObject:action];
    }

    UANotificationCategory *category = [UANotificationCategory categoryWithIdentifier:categoryId
                                                                              actions:actions
                                                                    intentIdentifiers:@[]
                                                                              options:UANotificationCategoryOptionNone];

    return category;
}

@end
