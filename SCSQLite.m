//
//  SCSQLite.m
//
//  Created by Lucas Correa on 21/12/11.
//  Copyright (c) 2011 Siriuscode Solutions. All rights reserved.
//

#import "SCSQLite.h"

static SCSQLite * _scsqlite = nil;

@implementation SCSQLite


#pragma mark -
#pragma mark Singleton

+(SCSQLite *)shared {    
    @synchronized (self){
        
        static dispatch_once_t pred;
        
        dispatch_once(&pred, ^{
            _scsqlite = [[SCSQLite alloc] init];
        });
    }
    
    return _scsqlite;
}



#pragma mark -
#pragma mark Public Methods Class 

+ (BOOL)executeSQL:(NSString*)sql{
    
    BOOL openDatabase;
	
	//Check if database is open and ready.
	if ([SCSQLite shared]->db == nil) {
		openDatabase = [[SCSQLite shared] openDatabase];
	}
	
	if (openDatabase) {		
		sqlite3_stmt *statement;	
		const char *query = [sql UTF8String];
		sqlite3_prepare_v2([SCSQLite shared]->db, query, -1, &statement, NULL);
		
		if (sqlite3_step(statement) == SQLITE_ERROR) {
            return NO;
		}
		sqlite3_finalize(statement);
		[[SCSQLite shared] closeDatabase];
	}
	else {
        return NO;
	}
    
	return YES;
}

+ (NSArray*) selectRowSQL:(NSString*)sql{
    NSMutableArray *resultsArray = [[[NSMutableArray alloc] initWithCapacity:1] autorelease];
	
	if ([SCSQLite shared]->db == nil) {
		[[SCSQLite shared] openDatabase];
	}
	
	sqlite3_stmt *statement;	
	const char *query = [sql UTF8String];
	sqlite3_prepare_v2([SCSQLite shared]->db, query, -1, &statement, NULL);
    
	while (sqlite3_step(statement) == SQLITE_ROW) {
        
		int columns = sqlite3_column_count(statement);
		NSMutableDictionary *result = [[[NSMutableDictionary alloc] initWithCapacity:columns] autorelease];
		
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
                    float value = sqlite3_column_int(statement, i);
                    [result setObject:[NSNumber numberWithFloat:value] forKey:columnName];
                    break;
				}
                    
				case SQLITE_TEXT:{
                    const char *value = (const char*)sqlite3_column_text(statement, i);
                    [result setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:columnName];
                    break;
				}
                    
				case SQLITE_BLOB:
					break;
                    
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

+(NSString*)getDatabaseDump {
	
	NSMutableString *dump = [[[NSMutableString alloc] initWithCapacity:256] autorelease];
	
	// info string ;) please do not remove it
	[dump appendString:@";\n; Dump generated with SCSQLite \n;\n"];
	[dump appendString:[NSString stringWithFormat:@"; database %@;\n", kDatabaseName]];
	
	// first get all table information
	
	NSArray *rows = [SCSQLite selectRowSQL:@"SELECT * FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"];
	
	//loop through all tables
	for (int i = 0; i<[rows count]; i++) {
		
		NSDictionary *obj = [rows objectAtIndex:i];
		//get sql "create table" sentence
		NSString *sql = [obj objectForKey:@"sql"];
		[dump appendString:[NSString stringWithFormat:@"%@;\n",sql]];
        
		//get table name
		NSString *tableName = [obj objectForKey:@"name"];
        
		//get all table content
		NSArray *tableContent = [SCSQLite selectRowSQL:[NSString stringWithFormat:@"SELECT * FROM %@",tableName]];
		
		for (int j = 0; j<[tableContent count]; j++) {
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
#pragma mark Private Methods

-(BOOL)openDatabase {
    
    NSString *databasePath;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];

    if (kDatabaseName != nil) {
        databasePath = [documentsDirectory stringByAppendingPathComponent:kDatabaseName];
    }else{
        databasePath = documentsDirectory;
    }
    
    //first check if exist
	if(![[NSFileManager defaultManager] fileExistsAtPath:databasePath]) {
        // if not, move pro mainbundle root to documents
		BOOL success = [[NSFileManager defaultManager] copyItemAtPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:kDatabaseName] toPath:databasePath error:nil];
		if (!success) return NO;
	}
    
    BOOL success = YES;
    
    if(!sqlite3_open([databasePath UTF8String], &db) == SQLITE_OK ) success = NO;
	
	return success;
}


-(BOOL)closeDatabase {
	
	if (db != nil) {
		
        if (sqlite3_close(db) != SQLITE_OK){
            return NO;
        }
        
		db = nil;
	}
    
	return YES;
}

@end