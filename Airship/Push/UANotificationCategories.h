/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class UANotificationCategory;

NS_ASSUME_NONNULL_BEGIN

/**
 * Utility methods to create categories from plist files or NSDictionaries.
 */
@interface UANotificationCategories : NSObject


/**
 * Creates a set of categories from the specified `.plist` file.
 *
 * Categories are defined in a plist dictionary with the category ID
 * followed by an NSArray of user notification action definitions. The
 * action definitions use the same keys as the properties on the action,
 * with the exception of "foreground" mapping to either UIUserNotificationActivationModeForeground
 * or UIUserNotificationActivationModeBackground. The required action definition
 * title can be defined with either the "title" or "title_resource" key, where
 * the latter takes precedence. If "title_resource" does not exist, the action
 * definition title will fall back to the value of "title". If the required action
 * definition title is not defined, the category will not be created.
 *
 * Example:
 *
 *  {
 *      "category_id" : [
 *          {
 *              "identifier" : "action ID",
 *              "title_resource" : "action title resource",
 *              "title" : "action title",
 *              "foreground" : @YES,
 *              "authenticationRequired" : @NO,
 *              "destructive" : @NO
 *          }]
 *  }
 *
 * @param filePath The path of the `.plist` file.
 * @return A set of categories.
 */
+ (NSSet *)createCategoriesFromFile:(NSString *)filePath;

/**
 * Creates a user notification category with the specified ID and action definition.
 *
 * @param categoryId The category identifier
 * @param actionDefinitions An array of user notification action dictionaries used
 *        to construct UANotificationAction for the category.
 * @return The user notification category created or `nil` if an error occurred.
 */
+ (nullable UANotificationCategory *)createCategory:(NSString *)categoryId
                                            actions:(NSArray *)actionDefinitions;

@end

NS_ASSUME_NONNULL_END
