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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Interface wrapping sqlite database operations
 */
@interface UASQLite : NSObject

/**
 * Number of retries before timeout, defaults to 1
 */
@property (atomic, assign) NSInteger busyRetryTimeout;

/**
 * Path string to the sqlite DB
 */
@property (nonatomic, copy, nullable) NSString *dbPath;

/**
 * Initializes sqlite DB with provided path string
 *
 * @param aDBPath Path to the sqlite DB
 */
- (instancetype)initWithDBPath:(NSString *)aDBPath;

/**
 * Opens the sqlite DB
 *
 * @param aDBPath String representing path of SQLite DB
 * @return YES if sucessful NO if unsucessful
 */
- (BOOL)open:(NSString *)aDBPath;


/**
 * Closes the sqlite DB
 */
- (void)close;

/**
 * Gets the last sqlite error message
 *
 * @return Last error message string
 */
- (nullable NSString*)lastErrorMessage;

/**
 * Gets the last sqlite error code
 *
 * @return Last error code int
 */
- (NSInteger)lastErrorCode;

/**
 * Executes query on database given the database string and arguments
 *
 * @param sql Database string
 * @param ... Variable argument list
 * @return Last error code int
 */
- (nullable NSArray *)executeQuery:(NSString *)sql, ...;

/**
 * Executes query on database given the database string and arguments
 * @param sql Database string
 * @param args Array of arguments
 * @return Last error code int
 */
- (nullable NSArray *)executeQuery:(NSString *)sql arguments:(nullable NSArray *)args;

/**
 * Executes update on database
 *
 * @param sql Database string
 * @param ... Variable argument list
 * @return YES if update succeeded, NO if update failed
 */
- (BOOL)executeUpdate:(NSString *)sql, ...;

/**
 * Executes update on database
 *
 * @param sql Database string
 * @param args Arguments array
 * @return YES if update succeeded, NO if update failed
 */
- (BOOL)executeUpdate:(NSString *)sql arguments:(nullable NSArray *)args;

/**
 * Executes commit transaction on database
 *
 * @return YES if transaction succeeded, NO if transaction failed
 */
- (BOOL)commit;

/**
 * Executes rollback transaction on database
 *
 * @return YES if transaction succeeded, NO if transaction failed
 */
- (BOOL)rollback;

/**
 * Executes exclusive transaction on database
 *
 * @return YES if transaction succeeded, NO if transaction failed
 */
- (BOOL)beginTransaction;

/**
 * Executes deferred transaction on database
 *
 * @return YES if transaction succeeded, NO if transaction failed
 */
- (BOOL)beginDeferredTransaction;

/**
 * Checks if table exists in DB
 *
 * @param tableName Table name string
 * @return YES if table exists, NO if table does not exist
 */
- (BOOL)tableExists:(NSString*)tableName;

/**
 * Checks if index exists in DB
 *
 * @param indexName Index name string
 * @return YES if index exists, NO if index does not exist
 */
- (BOOL)indexExists:(NSString*)indexName;

@end

NS_ASSUME_NONNULL_END
