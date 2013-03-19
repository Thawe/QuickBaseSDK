//
//  QuickBase.h
//  QuickBase
//
//  Created by Tyler Hawe on 12/16/12.
//  Copyright (c) 2012 Tyler Hawe. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 *  Use the error domain to identify errors from QuickBase. 
 *  The error code will be from http://www.quickbase.com/api-guide/index.html
 */

#define QUICKBASE_ERROR_DOMAIN @"QuickBaseErrorDomain"

@interface QuickBase : NSObject

#pragma mark -
#pragma mark - Host Name Method (Public)

/*
 *  If you don't set a host name then 'www.quickbase.com' will be used as a default.
 *
 *  EXAMPLE:
 *  [QuickBase setHostName:@"myCompanyName.quickbase.com"];
 */

+ (void)setHostName:(NSString *)hostName;
+ (NSString *)getHostName;

#pragma mark -
#pragma mark - API Methods (Public)

/*
 *  You will be forwarded NSErrors with the 'QUICKBASE_ERROR_DOMAIN' domain with the error code from QuickBase
 */

+ (void)QB_DoQueryForDBID:(NSString *)dbid
                    clist:(NSString *)clist
                    query:(NSString *)query
                 appToken:(NSString *)token
                 interval:(int)interval
         lastDateModified:(id)lastDateModified
            callbackBlock:(void (^)(NSData *xml, NSError *error))block;

+ (void)QB_GetSchemaForDBID:(NSString *)dbid
                   appToken:(NSString *)token
           lastDateModified:(id)lastDateModified
              callbackBlock:(void (^)(NSData *xml, NSError *error))block;

+ (void)QB_AddRecordToDBID:(NSString *)dbid
                  appToken:(NSString *)token
                    values:(NSDictionary *)values
             callbackBlock:(void (^)(NSData *xml, NSError *error))block;

+ (void)QB_EditRecord:(NSString *)rid
               toDBID:(NSString *)dbid
             appToken:(NSString *)token
               values:(NSDictionary *)values
        callbackBlock:(void (^)(NSData *xml, NSError *error))block;

+ (void)QB_AuthenticateUsername:(NSString *)username
                   withPassword:(NSString *)password
                       appToken:(NSString *)token
                  callbackBlock:(void (^)(NSData *xml, NSError *error))block;

#pragma mark -
#pragma mark - Credentials

/*
 *  Simply a wrapper around NSUserDefaults
 *  Set a user name and password here and they will be appended on each request
 */

+ (void)setUsername:(NSString *)username;

+ (void)setPassword:(NSString *)password;

+ (void)setUsername:(NSString *)username andPassword:(NSString *)password;

+ (NSString *)getUsername;

+ (NSString *)getPassword;

#pragma mark -
#pragma mark - Parse

+ (void)parseResponse:(NSData *)response callbackBlock:(void (^)(id object, NSError *error))block;

@end
