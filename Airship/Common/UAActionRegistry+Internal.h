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

#import "UAActionRegistry.h"

#define kUAIncomingInAppMessageActionDefaultRegistryName @"com.urbanairship.in_app"
#define kUACloseWindowActionRegistryName @"__close_window_action"

NS_ASSUME_NONNULL_BEGIN

@interface UAActionRegistry ()

/**
 * Map of names to action entries
 */
@property (nonatomic, strong) NSMutableDictionary *registeredActionEntries;

/**
 * An array of the reserved entry names
 */
@property (nonatomic, strong) NSMutableArray *reservedEntryNames;


/**
 * Registers a reserved action. Reserved actions can not be removed or modified.
 * @param action The action to be registered.
 * @param name The NSString name.
 * @param predicate The predicate.
 * @return `YES` if the action was registered, otherwise `NO`
 */
- (BOOL)registerReservedAction:(UAAction *)action
                          name:(NSString *)name
                     predicate:(nullable UAActionPredicate)predicate;

/**
 * Registers default actions.
 */
- (void)registerDefaultActions;

@end

NS_ASSUME_NONNULL_END
