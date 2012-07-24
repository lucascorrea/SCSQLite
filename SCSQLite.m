//
//  SCSQLite.m
//
//  Created by Lucas Correa on 21/12/11.
//  Copyright (c) 2012 Siriuscode Solutions. All rights reserved.
//

#import "SCSQLite.h"

@interface SCSQLite ()

- (BOOL)openDatabase;
- (BOOL)closeDatabase;

@end


@implementation SCSQLite

@synthesize database = _database;

#pragma mark -
#pragma mark - Singleton

+ (SCSQLite *)shared 
{        
    static SCSQLite * _scsqlite = nil;
    
    @synchronized (self){
        
        static dispatch_once_t pred;
        dispatch_once(&pred, ^{
            _scsqlite = [[SCSQLite alloc] init];
        });
    }
    
    return _scsqlite;
}



#pragma mark -
#pragma mark - Public Methods

+ (void)initWithDatabase:(NSString *)database
{
    [SCSQLite shared].database = database;
}

+ (BOOL)executeSQL:(NSString *)sql, ...
{    
    BOOL openDatabase = NO;
	
    va_list arguments;
    va_start(arguments, sql);
 //   NSLogv(sql, arguments);
    sql = [[NSString alloc] initWithFormat:sql arguments:arguments];
    va_end(arguments);
    
	//Check if database is open and ready.
	if ([SCSQLite shared]->db == nil) {
		openDatabase = [[SCSQLite shared] openDatabase];
	}
	
	if (openDatabase) {		
		sqlite3_stmt *statement;	
		const char *query = [sql UTF8String];
        char *errmsg;
        
        // prepare
        if (sqlite3_prepare_v2([SCSQLite shared]->db, query, -1, &statement, NULL) != SQLITE_OK) {
            NSLog(@"Error: failed to prepare statement with message '%s'.", sqlite3_errmsg([SCSQLite shared]->db));
            return NO;
        }
        
        // execute
        while (1) {
            if(sqlite3_exec([SCSQLite shared]->db, query, nil, &statement, &errmsg) == SQLITE_OK){
                
                sqlite3_finalize(statement);
                [[SCSQLite shared] closeDatabase];
                
                return YES;
            }else {
                NSLog(@" 2. Error %d: '%s' com sql: %@", sqlite3_errcode([SCSQLite shared]->db), sqlite3_errmsg([SCSQLite shared]->db), sql);
                if(sqlite3_errcode([SCSQLite shared]->db) != SQLITE_LOCKED){
                    
                    sqlite3_finalize(statement);
                    [[SCSQLite shared] closeDatabase];
                    
                    return NO;
                }
                
                [NSThread sleepForTimeInterval:.1];
            }
        }
	}
	else {
        return NO;
	}
    
	return YES;
}

+ (NSArray *)selectRowSQL:(NSString *)sql, ...
{
    
    va_list arguments;
    va_start(arguments, sql);
 //   NSLogv(sql, arguments);
    sql = [[NSString alloc] initWithFormat:sql arguments:arguments];
    va_end(arguments);
    
    NSMutableArray *resultsArray = [[NSMutableArray alloc] initWithCapacity:1];
	
	if ([SCSQLite shared]->db == nil) {
		[[SCSQLite shared] openDatabase];
	}
	
	sqlite3_stmt *statement;	
	const char *query = [sql UTF8String];
	sqlite3_prepare_v2([SCSQLite shared]->db, query, -1, &statement, NULL);
    
	while (sqlite3_step(statement) == SQLITE_ROW) {
        
		int columns = sqlite3_column_count(statement);
		NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:columns];
		
        for (int i = 0; i<columns; i++) {
			const char *name = sqlite3_column_name(statement, i);	
            
			NSString *columnName = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
			
			int type = sqlite3_column_type(statement, i);
            
			switch (type) {
                    
				case SQLITE_INTEGER:{
                    int value = sqlite3_column_int(statement, i);
                    [result setObject:[NSNumber numberWithInt:value] forKey:columnName];
                    break;
				}
                    
				case SQLITE_FLOAT:{
                    float value = sqlite3_column_double(statement, i);
                    [result setObject:[NSNumber numberWithFloat:value] forKey:columnName];
                    break;
				}
                    
				case SQLITE_TEXT:{
                    const char *value = (const char*)sqlite3_column_text(statement, i);
                    [result setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:columnName];
                    break;
				}
                    
				case SQLITE_BLOB:{
                    int dataSize = sqlite3_column_bytes(statement, i);
                    NSMutableData *data = [NSMutableData dataWithLength:dataSize];
                    memcpy([data mutableBytes], sqlite3_column_blob(statement, i), dataSize);
                    [result setObject:data forKey:columnName];                    
					break;
                }
                    
				case SQLITE_NULL:
					[result setObject:[NSNull null] forKey:columnName];
					break;
                    
				default:{
                    const char *value = (const char *)sqlite3_column_text(statement, i);
                    [result setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:columnName];
                    break;
				}
			}	
		}
		
		[resultsArray addObject:result];
        
	} 
    
	sqlite3_finalize(statement);
	
	[[SCSQLite shared] closeDatabase];
	
	return resultsArray;
}

+ (NSString *)getDatabaseDump 
{	
	NSMutableString *dump = [[NSMutableString alloc] initWithCapacity:256];
	
	// info string ;) please do not remove it
	[dump appendString:@";\n; Dump generated with SCSQLite \n;\n"];
	[dump appendString:[NSString stringWithFormat:@"; database %@;\n\n", [SCSQLite shared].database]];
	
	// first get all table information
	
	NSArray *rows = [SCSQLite selectRowSQL:@"SELECT * FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%%';"];
	
	//loop through all tables
	for (int i = 0; i<[rows count]; i++) {
		
		NSDictionary *obj = [rows objectAtIndex:i];
		//get sql "create table" sentence
		NSString *sql = [obj objectForKey:@"sql"];
		[dump appendString:[NSString stringWithFormat:@"%@;\n",sql]];
        
		//get table name
		NSString *tableName = [obj objectForKey:@"name"];
        
		//get all table content
		NSArray *tableContent = [SCSQLite selectRowSQL:@"SELECT * FROM %@",tableName];
		
		for (int j = 0; j < [tableContent count]; j++) {
			NSDictionary *item = [tableContent objectAtIndex:j];
			
			//keys are column names
			NSArray *keys = [item allKeys];
			
			//values are column values
			NSArray *values = [item allValues];
			
			//start constructing insert statement for this item
			[dump appendString:[NSString stringWithFormat:@"insert into %@ (",tableName]];
			
			//loop through all keys (aka column names)
			NSEnumerator *enumerator = [keys objectEnumerator];
			id obj;
			while ((obj = [enumerator nextObject])) {
				[dump appendString:[NSString stringWithFormat:@"%@,",obj]];
			}
			
			//delete last comma
			NSRange range;
			range.length = 1;
			range.location = [dump length]-1;
			[dump deleteCharactersInRange:range];
			[dump appendString:@") values ("];
			
			// loop through all values
			// value types could be:
			// NSNumber for integer and floats, NSNull for null or NSString for text.
			
			enumerator = [values objectEnumerator];
			while ((obj = [enumerator nextObject])) {
				//if it's a number (integer or float)
				if ([obj isKindOfClass:[NSNumber class]]){
					[dump appendString:[NSString stringWithFormat:@"%@,",[obj stringValue]]];
				}
				//if it's a null
				else if ([obj isKindOfClass:[NSNull class]]){
					[dump appendString:@"null,"];
				}
				//else is a string ;)
				else{
					[dump appendString:[NSString stringWithFormat:@"'%@',",obj]];
				}
				
			}
			
			//delete last comma again
			range.length = 1;
			range.location = [dump length]-1;
			[dump deleteCharactersInRange:range];
			
			//finish our insert statement
			[dump appendString:@");\n"];
			
		}
	}
    
	return dump;
}



#pragma mark - 
#pragma mark - Private Methods

- (BOOL)openDatabase 
{    
    NSString *databasePath;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    if (self.database != nil) {
        databasePath = [documentsDirectory stringByAppendingPathComponent:self.database];
    }else{
        [[[UIAlertView alloc] initWithTitle:@"Alert" message:@"It is necessary to initialize the database name of the sqlite" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        
        return NO;
    }
    
    //first check if exist
	if(![[NSFileManager defaultManager] fileExistsAtPath:databasePath]) {
        // if not, move pro mainbundle root to documents
		BOOL success = [[NSFileManager defaultManager] copyItemAtPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.database] toPath:databasePath error:nil];
		if (!success) return NO;
	}
    
    BOOL success = YES;
    
    if(!sqlite3_open([databasePath UTF8String], &db) == SQLITE_OK ) success = NO;
	
	return success;
}


- (BOOL)closeDatabase 
{	
	if (db != nil) {
        if (sqlite3_close(db) != SQLITE_OK){
            return NO;
        }
        
		db = nil;
	}
    
	return YES;
}

@end