//
//  SCSQLite.h
//
//  Created by Lucas Correa on 21/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.


#import <Foundation/Foundation.h>
#import "sqlite3.h"

#warning Input name file of database
#define kDatabaseName @""

@interface SCSQLite : NSObject {
	sqlite3 *db;
}

+(SCSQLite *)shared;
+(BOOL)executeSQL:(NSString*)sql;
+(NSArray*)selectRowSQL:(NSString*)sql;
+(NSString*)getDatabaseDump;


-(BOOL)openDatabase;
-(BOOL)closeDatabase;


@end
