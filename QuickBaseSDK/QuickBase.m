//
//  QuickBase.m
//  QuickBase
//
//  Created by Tyler Hawe on 12/16/12.
//  Copyright (c) 2012 Tyler Hawe. All rights reserved.
//

#import "QuickBase.h"
#import "RXMLElement.h"
#import <MKNetworkKit.h>

static dispatch_queue_t serialParsingQueue;

dispatch_queue_t action_queue_parsing(void);
dispatch_queue_t action_queue_parsing(void)
{
    if (serialParsingQueue == NULL)
    {
        serialParsingQueue = dispatch_queue_create("com.quickbasekit.actionQueueParsing", DISPATCH_QUEUE_SERIAL);
    }
    return serialParsingQueue;
}

#define GetSchemaDateKey(key) [NSString stringWithFormat:@"Schema%@", key]

@implementation QuickBase

#pragma mark -
#pragma mark - API Methods (Public)

+ (void)QB_DoQueryForDBID:(NSString *)dbid
                    clist:(NSString *)clist
                    query:(NSString *)query
                 appToken:(NSString *)token
                 interval:(int)interval
         lastDateModified:(id)lastDateModified
            callbackBlock:(void (^)(NSData *, NSError *))block
{
    dispatch_block_t backgroundBlock = ^{
        
        NSString *requestBody = [QuickBase generateRequestBodyForFieldsToPost:nil
                                                                  fieldsToGet:clist
                                                                    fromQuery:[QuickBase formatDateQuery:query
                                                                                                 forDbid:dbid
                                                                                        lastDateModified:lastDateModified]
                                                                     recordID:nil
                                                                     appToken:token];
        
        [QuickBase createNetworkOperationForEngine:[QuickBase sharedDoQueryEngine]
                                        attributes:nil
                                        databaseID:dbid
                                       requestBody:requestBody
                                         freezable:NO
                                     callbackBlock:block];
        
        [QuickBase setDateForKey:dbid];
    };
    
    dispatch_async(action_queue_parsing(), backgroundBlock);
}

+ (void)QB_GetSchemaForDBID:(NSString *)dbid
                   appToken:(NSString *)token
           lastDateModified:(id)lastDateModified
              callbackBlock:(void (^)(NSData *, NSError *))block
{
    dispatch_block_t backgroundBlock = ^{
        
        NSString *requestBody = [QuickBase generateRequestBodyForFieldsToPost:nil
                                                                  fieldsToGet:nil
                                                                    fromQuery:nil
                                                                     recordID:nil
                                                                     appToken:token];
        
        [QuickBase createNetworkOperationForEngine:[QuickBase sharedGetSchemaEngine]
                                        attributes:lastDateModified
                                        databaseID:dbid
                                       requestBody:requestBody
                                         freezable:NO
                                     callbackBlock:block];
        
        [QuickBase setDateForKey:GetSchemaDateKey(dbid)];
    };
    
    dispatch_async(action_queue_parsing(), backgroundBlock);
}

+ (void)QB_AddRecordToDBID:(NSString *)dbid
                  appToken:(NSString *)token
                    values:(NSDictionary *)values
             callbackBlock:(void (^)(NSData *, NSError *))block
{
    dispatch_block_t backgroundBlock = ^{
        
        NSString *requestBody = [QuickBase generateRequestBodyForFieldsToPost:values fieldsToGet:nil fromQuery:nil recordID:nil appToken:token];
        
        [QuickBase createNetworkOperationForEngine:[QuickBase sharedAddEngine]
                                        attributes:nil
                                        databaseID:dbid
                                       requestBody:requestBody
                                         freezable:YES
                                     callbackBlock:block];
    };
    
    dispatch_async(action_queue_parsing(), backgroundBlock);
}

+ (void)QB_EditRecord:(NSString *)rid
               toDBID:(NSString *)dbid
             appToken:(NSString *)token
               values:(NSDictionary *)values
        callbackBlock:(void (^)(NSData *, NSError *))block
{
    dispatch_block_t backgroundBlock = ^{
        
        NSString *requestBody = [QuickBase generateRequestBodyForFieldsToPost:values fieldsToGet:nil fromQuery:nil recordID:rid appToken:token];
        
        [QuickBase createNetworkOperationForEngine:[QuickBase sharedEditEngine]
                                        attributes:nil
                                        databaseID:dbid
                                       requestBody:requestBody
                                         freezable:YES
                                     callbackBlock:block];
    };
    
    dispatch_async(action_queue_parsing(), backgroundBlock);
}

#pragma mark -
#pragma mark - Auth / User
+ (void)QB_AuthenticateUsername:(NSString *)username
                   withPassword:(NSString *)password
                       appToken:(NSString *)token
                  callbackBlock:(void (^)(NSData *, NSError *))block
{
    dispatch_block_t backgroundBlock = ^{
        
        [QuickBase setUsername:username andPassword:password];
        
        NSString *requestBody = [QuickBase generateRequestBodyForFieldsToPost:nil fieldsToGet:nil fromQuery:nil recordID:nil appToken:token];
        
        [QuickBase createNetworkOperationForEngine:[QuickBase sharedAuthEngine]
                                        attributes:nil
                                        databaseID:nil
                                       requestBody:requestBody
                                         freezable:NO
                                     callbackBlock:block];
    };
    
    dispatch_async(action_queue_parsing(), backgroundBlock);
}

#pragma mark -
#pragma mark - Request Body Methods (Private)

+ (NSString *)generateRequestBodyForFieldsToPost:(NSDictionary *)fieldsToPost
                                     fieldsToGet:(NSString *)clist
                                       fromQuery:(NSString *)query
                                        recordID:(NSString *)recordID
                                        appToken:(NSString *)token
{
    NSMutableString *requestBody = [[NSMutableString alloc] init];
    
    [requestBody appendString:@"<qdbapi>"];
    if (recordID != nil) [requestBody appendFormat:@"<rid>%@</rid>", recordID];
    if (query != nil) [requestBody appendFormat:@"<query>%@</query>", query];
    if (clist != nil) [requestBody appendFormat:@"<clist>%@</clist>", clist];
    if (fieldsToPost != nil) [requestBody appendString:[self formatFieldsToPushForDict:fieldsToPost]];
    if (token != nil) [requestBody appendFormat:@"<apptoken>%@</apptoken>", token];
    [requestBody appendFormat:@"<username>%@</username><password>%@</password>", [self getUsername], [self getPassword]];
    //[requestBody appendFormat:@"<fmt>structured</fmt>"];
    [requestBody appendString:@"</qdbapi>"];
    
    return requestBody;
}

+ (NSString *)formatFieldsToPushForDict:(NSDictionary *)dict
{
    __block NSMutableString *fields = [[NSMutableString alloc] init];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [fields appendString:[self setObject:obj forFieldID:key]];
    }];
    return fields;
}

+ (NSString *)setObject:(id)anObject forFieldID:(id)fid
{
#if TARGET_OS_IPHONE
    if ([anObject isKindOfClass:[UIImage class]])
    {
        return [self setUploadData:UIImagePNGRepresentation(anObject) forFieldID:fid imageName:@"image.png"];
    }
#elif TARGET_OS_MAC
    if ([anObject isKindOfClass:[NSImage class]])
    {
        return [self setUploadData:[[[anObject representations] objectAtIndex: 0] representationUsingType:NSPNGFileType properties:nil] forFieldID:fid imageName:@"image.png"];
    }
#endif
    if ([anObject isKindOfClass:[NSData class]])
    {
        return [self setUploadData:anObject forFieldID:fid imageName:@"recording.mp3"];
    }
    return [NSString stringWithFormat:@"<field fid=\"%@\">%@</field>", fid, anObject];
}

+ (NSString *)setUploadData:(NSData *)data forFieldID:(id)fid imageName:(NSString *)name
{
    return [NSString stringWithFormat:@"<field fid=\"%@\" filename=\"%@\">%@</field>", fid, name, [self base64StringFromData:data]];
}

#pragma mark -
#pragma mark - Last Date Modified Methods (Private)

+ (NSString *)formatDateQuery:(NSString *)query forDbid:(NSString *)dbid lastDateModified:(id)lastDateModified
{
    if ([lastDateModified isKindOfClass:[NSNumber class]])
    {
        NSNumber *num = (NSNumber *)lastDateModified;
        if (!num.boolValue) return query;
        return query != nil ?
        [NSString stringWithFormat:@"%@AND{'2'.OAF.'%@'}", query, [self getDateStringForKey:dbid]] :
        [NSString stringWithFormat:@"{'2'.OAF.'%@'}", [self getDateStringForKey:dbid]];
    }
    if ([lastDateModified isKindOfClass:[NSDate class]])
    {
        return query != nil ?
        [NSString stringWithFormat:@"%@AND{'2'.OAF.'%@'}", query, [self getDateStringFromDate:lastDateModified]] :
        [NSString stringWithFormat:@"{'2'.OAF.'%@'}", [self getDateStringFromDate:lastDateModified]];
    }
    if ([lastDateModified isKindOfClass:[NSString class]])
    {
        NSParameterAssert([lastDateModified length] == 13);
        return query != nil ?
        [NSString stringWithFormat:@"%@AND{'2'.OAF.'%@'}", query, lastDateModified] :
        [NSString stringWithFormat:@"{'2'.OAF.'%@'}", lastDateModified];
    }
    return query;
}

+ (NSString *)getDateStringForKey:(NSString *)key
{
    return [self getDateStringFromDate:[[NSUserDefaults standardUserDefaults] objectForKey:key]];
}

+ (NSString *)getDateStringFromDate:(NSDate *)date
{
    NSString *dateString = nil;
    
    if (date == nil) {
        
        dateString = @"0";
        
    } else {
        
        NSTimeInterval interval = [date timeIntervalSince1970];
        
        interval*=1000;
        
        dateString = [NSString stringWithFormat:@"%.0f", interval];
    }
    
    return dateString;
}

+ (void)setDateForKey:(NSString *)key
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:key];
}

#pragma mark -
#pragma mark - Network Request Methods (Private)

+ (void)createNetworkOperationForEngine:(MKNetworkEngine *)engine
                             attributes:(id)attributesobj
                             databaseID:(NSString *)dbid
                            requestBody:(NSString *)requestBody
                              freezable:(BOOL)shouldFreeze
                          callbackBlock:(void (^)(NSData *, NSError *))block
{
    MKNetworkOperation *anOp = [engine operationWithPath:dbid == nil ? @"db/main?" : [NSString stringWithFormat:@"db/%@?", dbid]
                                                  params:nil
                                              httpMethod:@"POST"
                                                     ssl:YES];
    
    anOp.freezable = shouldFreeze;
    anOp.postDataEncoding = MKNKPostDataEncodingTypeCustom;
    
    [anOp setCustomPostDataEncodingHandler:^NSString *(NSDictionary *postDataDict) {
        return requestBody;
    } forType:@"application/xml"];
    
    [anOp addCompletionHandler:^(MKNetworkOperation *completedOperation) {
        //NSLog(@"CompletedOperation: %@", [completedOperation responseString]);
        
        if (block)
            block([completedOperation responseData], nil);
        
    } errorHandler:^(MKNetworkOperation *completedOperation, NSError *error) {
        
        if (block)
            block([completedOperation responseData], error);
    }];
    
    [engine enqueueOperation:anOp];
    
    //NSLog(@"Operation: %@", [anOp curlCommandLineString]);
}

#pragma mark -
#pragma mark - Credentials Methods (Public)

+ (void)setUsername:(NSString *)username
{
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"QuickBaseUsername"];
}

+ (void)setPassword:(NSString *)password
{
    [[NSUserDefaults standardUserDefaults] setObject:password forKey:@"QuickBasePassword"];
}

+ (void)setUsername:(NSString *)username andPassword:(NSString *)password
{
    [self setUsername:username];
    [self setPassword:password];
}

+ (NSString *)getUsername
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"QuickBaseUsername"];
}

+ (NSString *)getPassword
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"QuickBasePassword"];
}

#pragma mark -
#pragma mark - Host Name Method (Public)

+ (void)setHostName:(NSString *)hostName
{
    [[NSUserDefaults standardUserDefaults] setObject:hostName forKey:@"QuickBaseHostName"];
}

+ (NSString *)getHostName
{
    NSString *hostName = [[NSUserDefaults standardUserDefaults] objectForKey:@"QuickBaseHostName"];
    return hostName.length > 0 ? hostName : @"www.quickbase.com";
}

#pragma mark -
#pragma mark - MKNetworkKit Engines (Private)

+ (MKNetworkEngine *)sharedAddEngine
{
    static MKNetworkEngine *addEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        addEngine = [[MKNetworkEngine alloc] initWithHostName:[self getHostName]
                                           customHeaderFields:[NSDictionary dictionaryWithObject:@"API_AddRecord" forKey:@"QUICKBASE-ACTION"]];
    });
    return addEngine;
}

+ (MKNetworkEngine *)sharedEditEngine
{
    static MKNetworkEngine *editEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        editEngine = [[MKNetworkEngine alloc] initWithHostName:[self getHostName]
                                            customHeaderFields:[NSDictionary dictionaryWithObject:@"API_EditRecord" forKey:@"QUICKBASE-ACTION"]];
    });
    return editEngine;
}

+ (MKNetworkEngine *)sharedAuthEngine
{
    static MKNetworkEngine *authEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        authEngine = [[MKNetworkEngine alloc] initWithHostName:[self getHostName]
                                            customHeaderFields:[NSDictionary dictionaryWithObject:@"API_Authenticate" forKey:@"QUICKBASE-ACTION"]];
    });
    return authEngine;
}

+ (MKNetworkEngine *)sharedGrantedDBsEngine
{
    static MKNetworkEngine *grantedDBsEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        grantedDBsEngine = [[MKNetworkEngine alloc] initWithHostName:[self getHostName]
                                                  customHeaderFields:[NSDictionary dictionaryWithObject:@"API_GrantedDBs" forKey:@"QUICKBASE-ACTION"]];
    });
    return grantedDBsEngine;
}

+ (MKNetworkEngine *)sharedDoQueryEngine
{
    static MKNetworkEngine *doQueryEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        doQueryEngine = [[MKNetworkEngine alloc] initWithHostName:[self getHostName]
                                               customHeaderFields:[NSDictionary dictionaryWithObject:@"API_DoQuery" forKey:@"QUICKBASE-ACTION"]];
    });
    return doQueryEngine;
}

+ (MKNetworkEngine *)sharedGetSchemaEngine
{
    static MKNetworkEngine *getSchemaEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        getSchemaEngine = [[MKNetworkEngine alloc] initWithHostName:[self getHostName]
                                                 customHeaderFields:[NSDictionary dictionaryWithObject:@"API_GetSchema" forKey:@"QUICKBASE-ACTION"]];
    });
    return getSchemaEngine;
}

+ (MKNetworkEngine *)sharedGetUserRoleEngine
{
    static MKNetworkEngine *getUserRoleEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        getUserRoleEngine = [[MKNetworkEngine alloc] initWithHostName:[self getHostName]
                                                   customHeaderFields:[NSDictionary dictionaryWithObject:@"API_GetUserRole" forKey:@"QUICKBASE-ACTION"]];
    });
    return getUserRoleEngine;
}

#pragma mark -
#pragma mark - Parsing Methods (Public)

+ (void)parseResponse:(NSData *)response callbackBlock:(void (^)(id, NSError *))block
{
    RXMLElement *rootXML = [RXMLElement elementFromXMLData:response];
    
    [rootXML iterate:@"errcode" usingBlock:^(RXMLElement *errcode) {
        if (errcode.textAsInt == 0)//All Good
        {
            [rootXML iterate:@"action" usingBlock:^(RXMLElement *action) {
                
                if ([action.text isEqualToString:@"API_DoQuery"])
                {
                    __block NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    __block NSMutableArray *dictArray = [NSMutableArray new];
                    
                    [rootXML iterate:@"record" usingBlock:^(RXMLElement *element) {
                        [dict removeAllObjects];
                        [element iterate:@"*" usingBlock:^(RXMLElement *innerElement) {
                            if (innerElement.text.length > 0) [dict setValue:innerElement.text forKey:innerElement.tag];
                        }];
                        [dictArray addObject:dict];
                    }];
                    if (block)
                        block(dictArray, nil);
                }
                else if ([action.text isEqualToString:@"API_Authenticate"])
                {
                    __block NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    [rootXML iterate:@"ticket" usingBlock:^(RXMLElement *element) {
                        [dict setValue:element.text forKey:element.tag];
                    }];
                    [rootXML iterate:@"userid" usingBlock:^(RXMLElement *element) {
                        [dict setValue:element.text forKey:element.tag];
                    }];
                    if (block)
                        block(dict, nil);
                }
                
                else if ([action.text isEqualToString:@"API_GetSchema"])
                {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    NSMutableArray *dictsArray = [NSMutableArray array];
                    __block BOOL hasChoices = NO;
                    __block NSString *tableID = nil;
                    
                    [rootXML iterate:@"table.original.table_id" usingBlock:^(RXMLElement *tableElements) {
                        tableID = tableElements.text;
                    }];
                    
                    [rootXML iterate:@"table.fields.field" usingBlock:^(RXMLElement *field) {
                        [dict removeAllObjects];
                        [dict setValue:[field attribute:@"id"] forKey:@"id"];
                        [dict setValue:tableID forKey:@"table_id"];
                        if ([field attribute:@"field_type"] != nil) [dict setValue:[field attribute:@"field_type"] forKey:@"field_type"];
                        if ([field attribute:@"base_type"] != nil) [dict setValue:[field attribute:@"base_type"] forKey:@"base_type"];
                        if ([field attribute:@"mode"] != nil) [dict setValue:[field attribute:@"mode"] forKey:@"mode"];
                        if ([field attribute:@"role"] != nil) [dict setValue:[field attribute:@"role"] forKey:@"role"];
                        
                        [field iterate:@"*" usingBlock:^(RXMLElement *fieldElements) {
                            
                            if ([fieldElements.tag isEqualToString:@"choices"])
                            {
                                hasChoices = YES;
                            }
                            else
                            {
                                [dict setValue:fieldElements.text forKey:fieldElements.tag];
                            }
                        }];
                        
                        if (hasChoices)
                        {
                            NSMutableArray *choicesArray = [NSMutableArray array];
                            [field iterate:@"choices.choice" usingBlock:^(RXMLElement *choice) {
                                if (choice.text.length > 0)
                                {
                                    [choicesArray addObject:choice.text];
                                }
                            }];
                            hasChoices = NO;
                            [dict setValue:choicesArray forKey:@"choices"];
                        }
                        [dictsArray addObject:dict];
                    }];
                    
                    if (block)
                        block(dictsArray, nil);
                }
                
                else if ([action.text isEqualToString:@"API_AddRecord"] || [action.text isEqualToString:@"API_EditRecord"])
                {
                    [rootXML iterate:@"rid" usingBlock:^(RXMLElement *recordID) {
                        if (block)
                            block(recordID.text, nil);
                    }];
                }
            }];
        }
        else
        {
            if (block)
                block(nil, [NSError errorWithDomain:QUICKBASE_ERROR_DOMAIN code:errcode.textAsInt userInfo:nil]);
        }
    }];
}

#pragma mark -
#pragma mark - Base64

static char base64EncodingTable[64] = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/'
};

+ (NSString *)base64StringFromData:(NSData *)data
{
    NSUInteger lentext = [data length];
    if (lentext < 1) return @"";
    
    char *outbuf = malloc(lentext*4/3+4); // add 4 to be sure
    
    if ( !outbuf ) return nil;
    
    const unsigned char *raw = [data bytes];
    
    int inp = 0;
    int outp = 0;
    NSUInteger do_now = lentext - (lentext%3);
    
    for ( outp = 0, inp = 0; inp < do_now; inp += 3 )
    {
        outbuf[outp++] = base64EncodingTable[(raw[inp] & 0xFC) >> 2];
        outbuf[outp++] = base64EncodingTable[((raw[inp] & 0x03) << 4) | ((raw[inp+1] & 0xF0) >> 4)];
        outbuf[outp++] = base64EncodingTable[((raw[inp+1] & 0x0F) << 2) | ((raw[inp+2] & 0xC0) >> 6)];
        outbuf[outp++] = base64EncodingTable[raw[inp+2] & 0x3F];
    }
    
    if ( do_now < lentext )
    {
        unsigned char tmpbuf[3] = {0,0,0};
        int left = lentext%3;
        for ( int i=0; i < left; i++ )
        {
            tmpbuf[i] = raw[do_now+i];
        }
        raw = tmpbuf;
        inp = 0;
        outbuf[outp++] = base64EncodingTable[(raw[inp] & 0xFC) >> 2];
        outbuf[outp++] = base64EncodingTable[((raw[inp] & 0x03) << 4) | ((raw[inp+1] & 0xF0) >> 4)];
        if ( left == 2 ) outbuf[outp++] = base64EncodingTable[((raw[inp+1] & 0x0F) << 2) | ((raw[inp+2] & 0xC0) >> 6)];
        else outbuf[outp++] = '=';
        outbuf[outp++] = '=';
    }
    
    NSString *ret = [[NSString alloc] initWithBytes:outbuf length:outp encoding:NSASCIIStringEncoding];
    free(outbuf);
    
    return ret;
}

@end
