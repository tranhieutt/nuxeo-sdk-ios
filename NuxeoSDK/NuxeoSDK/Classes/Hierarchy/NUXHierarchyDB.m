//
//  NUXHierarchyDB.m
//  NuxeoSDK
//
//  Created by Arnaud Kervern on 03/12/13.
//  Copyright (c) 2013 Nuxeo. All rights reserved.
//

#import "NUXHierarchyDB.h"
#import "NUXSQLiteDatabase.h"
#import "NUXDocument.h"
#import "NUXHierarchy.h"

#define kHierarchyTable @"hierarchyNode"

@implementation NUXHierarchyDB {
    NUXSQLiteDatabase* _db;
}

-(id)init {
    self = [super init];
    if (self) {
        _db = [NUXSQLiteDatabase shared];
    }
    return self;
}

-(void)dealloc {
    _db = nil;
}

#pragma mark
#pragma internal

-(void)createTableIdNeeded {
    [_db createTableIfNotExists:kHierarchyTable withField:@"'hierarchyName' TEXT, 'docId' TEXT, 'parentId' TEXT, 'content' TEXT, 'order' INTEGER"];
}

-(void)insertNodes:(NSArray *)docs fromHierarchy:(NSString *)hierarchyName withParent:(NSString *)parentId {
    NSString *columns = [NUXHierarchyDB sqlitize:@[@"hierarchyName", @"docId", @"parentId", @"content", @"order"]];
    NSString *bQuery = [NSString stringWithFormat:@"insert into %@ (%@) values (%@)", kHierarchyTable, columns, @"%@"];
    [docs enumerateObjectsUsingBlock:^(NUXDocument *doc, NSUInteger idx, BOOL *stop) {
        NSString *values = [NUXHierarchyDB sqlitize:@[hierarchyName, doc.uid, parentId, @"", @(idx)]];
        if (![_db executeQuery:[NSString stringWithFormat:bQuery, values]]) {
            // Handle error
            NUXDebug(@"%@", [_db sqlInformatiomFromCode:[_db lastReturnCode]]);
        }
    }];
}

-(NSArray *)selectNodesFromParent:(NSString *)parentId hierarchy:(NSString *)hierarchyName {
    NSString *query = [NSString stringWithFormat:@"select docId, content from %@ where parentId = '%@' and hierarchyName = '%@' order by 'order'", kHierarchyTable, parentId, hierarchyName];
//    NSString *query = [NSString stringWithFormat:@"SELECT parentId, docId, content FROM '%@' WHERE parentId = '/'", kHierarchyTable];
    NSArray *ret = [_db arrayOfObjectsFromQuery:query block:^id(sqlite3_stmt *stmt) {
        // Should fetch Document JSON from storage.
        NUXDocument *doc = [NUXDocument new];
        doc.uid = [NSString stringWithCString:(const char*)sqlite3_column_text(stmt, 0) encoding:NSUTF8StringEncoding];
        return doc;
    }];
    return ret;
}

#pragma mark
#pragma shared accessor

+(NSString *)sqlitize:(NSArray *)values {
    NSMutableString *ret = [NSMutableString new];
    [values enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
        if (idx > 0) {
            [ret appendString:@", "];
        }
        
        if (![value isKindOfClass:[NSNumber class]]) {
            [ret appendString:[NSString stringWithFormat:@"\"%@\"", value]];
        } else {
            [ret appendString:[NSString stringWithFormat:@"%@", value]];
        }
    }];
    
    return ret;
}

+ (NUXHierarchyDB *)shared {
    static dispatch_once_t pred = 0;
    static NUXHierarchyDB *__strong _shared = nil;
    
    dispatch_once(&pred, ^{
        _shared = [NUXHierarchyDB new];
        [_shared createTableIdNeeded];
    });
    
    return _shared;
}

@end
