//
//  Owl2Manager+Database.m
//  PrivacyProtect
//
//  Copyright © 2025 Tencent. All rights reserved.
//

#import "Owl2Manager+Database.h"
#import "Owl2Manager+LocaFile.h"
#import "Owl2AppItem.h"

#define kTableBackUp(name) [NSString stringWithFormat:@"%@_backup", name]

static NSInteger kDatabaseVersion = 3;

@implementation Owl2Manager (Database)

- (void)createVersionTable {
    NSString *sqlStatement = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ ("
                              "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                              "version INTEGER NOT NULL, "
                              "change_log TEXT, "
                              "updated_at DATETIME DEFAULT CURRENT_TIMESTAMP);", OwlVersionTable];
    
    if (![db executeUpdate:sqlStatement]) {
        NSLog(@"Failed to create table: %@", [db lastErrorMessage]);
    } else {
        NSLog(@"Version table created successfully!");
    }
}

- (void)createProfileTable
{
    BOOL result = [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (id integer PRIMARY KEY AUTOINCREMENT, %@ integer DEFAULT 0, %@ integer DEFAULT 0, %@ integer DEFAULT 0, %@ integer DEFAULT 0);", OwlProcProfileTable, OwlWatchCamera, OwlWatchAudio, OwlWatchScreen, OwlWatchAutomatic]];
    if (result)
    {
        
    } else {
        NSLog(@"Error owl create proc_profile table fail %d: %@", [db lastErrorCode], [db lastErrorMessage]);
    }
}

- (void)createLogTable
{
    BOOL result = [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (id integer PRIMARY KEY AUTOINCREMENT, time text NOT NULL, %@ text NOT NULL,  event text NOT NULL);", OwlProcLogTable, OwlAppName]];
    if (result)
    {
        
    } else {
        NSLog(@"Error owl create proc_log table fail %d: %@", [db lastErrorCode], [db lastErrorMessage]);
    }
}

- (void)createLogTableNew
{
    NSString *strSQL = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (id integer PRIMARY KEY AUTOINCREMENT, %@ text NOT NULL, %@ text NOT NULL, %@ text NOT NULL,  %@ text, %@ integer NOT NULL, %@ integer NOT NULL, %@ integer NOT NULL);", OwlProcLogTableNew, OwlUUID, OwlTime, OwlAppName, OwlAppIconPath, OwlAppAction, OwlUserAction, OwlHardware];
    BOOL result = [db executeUpdate:strSQL];
    if (result)
    {
        
    } else {
        NSLog(@"Error owl create proc_log table fail %d: %@", [db lastErrorCode], [db lastErrorMessage]);
    }
}

- (void)createWhiteAppTable
{
    NSString *strSQL = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@ text NOT NULL, %@ text NOT NULL, %@ text NOT NULL, %@ text PRIMARY KEY NOT NULL, %@ text NOT NULL, %@ integer NOT NULL, %@ integer NOT NULL, %@ integer NOT NULL, %@ integer NOT NULL, %@ integer NOT NULL, %@ integer NOT NULL);", OwlAppWhiteTable, OwlAppName, OwlExecutableName, OwlBubblePath, OwlIdentifier, OwlAppIcon, OwlAppleApp, OwlWatchCamera, OwlWatchAudio, OwlWatchSpeaker, OwlWatchScreen, OwlWatchAutomatic];
    BOOL result = [db executeUpdate:strSQL];
    if (result)
    {
        NSString *appsPath = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSSystemDomainMask, YES)[0];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *error = nil;
        for (NSString *name in [fm contentsOfDirectoryAtPath:appsPath error:&error]) {
            if ([[name pathExtension] isEqualToString:@"app"]) {
                if ([name isEqualToString:@"Siri.app"] ||
                    [name isEqualToString:@"Photo Booth.app"] ||
                    [name isEqualToString:@"FaceTime.app"]) {
                    NSString *appPath = [appsPath stringByAppendingPathComponent:name];
                    Owl2AppItem *appItem = [[Owl2AppItem alloc] initWithAppPath:appPath];
                    [appItem enableAllWatchSwitch];
                    [self addAppWhiteItemToDB:appItem.toDictionary];
                }
            }
        }
    } else {
        NSLog(@"Error owl create app_white table fail %d: %@", [db lastErrorCode], [db lastErrorMessage]);
    }
}

- (void)loadDB
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    NSString *support = [home stringByAppendingPathComponent:@"Library/Application Support/com.tencent.lemon/Owl"];
    dbPath = [support stringByAppendingPathComponent:@"owl.db"];
    if (![fm fileExistsAtPath:support]){
        NSError *error = nil;
        if (![fm createDirectoryAtPath:support withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"create owl support path fail");
        }
    }
    if (![fm fileExistsAtPath:dbPath]) {
        db = [FMDatabase databaseWithPath:dbPath];
        if ([db open])
        {
            [self createVersionTable];
            [self createLogTableNew];
            [self createProfileTable];
            [self createWhiteAppTable];
            [self insertCurrentVersionWithChangeLog:@"First time creation"];
            
        } else {
            NSLog(@"Error owl open db fail %d: %@  path:%@", [db lastErrorCode], [db lastErrorMessage], dbPath);
        }
    } else {
        db = [FMDatabase databaseWithPath:dbPath];
        if ([db open])
        {
            // 数据库的表更新
            [self updatetable];
            // LIMIT 10000 防止日志过多
            FMResultSet *resultSetLog = [db executeQuery:[NSString stringWithFormat:@"select * from %@ ORDER BY %@ DESC, %@ DESC LIMIT 10000", OwlProcLogTableNew, OwlTime, OwlAppAction]];
            NSLog(@"[resultSet columnCount]: %d", [resultSetLog columnCount]);
            NSLog(@"columnNameToIndexMap: %@", [[resultSetLog columnNameToIndexMap] allKeys]);
            while ([resultSetLog next])
            {
                NSString *uuid        = [resultSetLog objectForColumn:OwlUUID];
                NSString *time        = [resultSetLog objectForColumn:OwlTime];
                NSString *appName     = [resultSetLog objectForColumn:OwlAppName];
                NSString *appIconPath = [resultSetLog objectForColumn:OwlAppIconPath];
                NSNumber *appAction   = [resultSetLog objectForColumn:OwlAppAction];
                NSNumber *userAction  = [resultSetLog objectForColumn:OwlUserAction];
                NSNumber *hardware    = [resultSetLog objectForColumn:OwlHardware];
                
                NSMutableDictionary *appDic = [[NSMutableDictionary alloc] initWithCapacity:7];
                if (uuid)        [appDic setObject:time forKey:OwlTime];
                if (time)        [appDic setObject:time forKey:OwlTime];
                if (appName)     [appDic setObject:appName forKey:OwlAppName];
                if (appIconPath) [appDic setObject:appIconPath forKey:OwlAppIconPath];
                if (appAction)   [appDic setObject:appAction forKey:OwlAppAction];
                if (userAction)  [appDic setObject:userAction forKey:OwlUserAction];
                if (hardware)    [appDic setObject:hardware forKey:OwlHardware];
                
                if (uuid && time && appName && appIconPath) {
                    [self.logArray addObject:appDic];
                }
            }
            if ([db hadError]) {
                NSLog(@"Error %d: %@", [db lastErrorCode], [db lastErrorMessage]);
                [self createLogTableNew];
            }
            
            FMResultSet *resultProfile = [db executeQuery:[NSString stringWithFormat:@"select * from %@", OwlProcProfileTable]];
            int iprofile = 0;
            while ([resultProfile  next])
            {
                if (iprofile == 0) {
                    self.isWatchVideo = [resultProfile intForColumn:OwlWatchCamera];
                    self.isWatchAudio = [resultProfile intForColumn:OwlWatchAudio];
                    self.isWatchScreen = [resultProfile intForColumn:OwlWatchScreen];
                    self.isWatchAutomatic = [resultProfile intForColumn:OwlWatchAutomatic];
                }
                iprofile++;
            }
            //兼容历史数据，删除多余的row
            if (iprofile > 1) {
                [db executeUpdate:[NSString stringWithFormat:@"delete from %@", OwlProcProfileTable]];
                NSString *strSQL = [NSString stringWithFormat:@"INSERT INTO %@ (%@,%@,%@,%@,%@) VALUES  (?,?,?,?,?);", OwlProcProfileTable, @"id", OwlWatchCamera, OwlWatchAudio, OwlWatchScreen, OwlWatchAutomatic];
                [db executeUpdate:strSQL, @(1), @(self.isWatchVideo), @(self.isWatchAudio), @(self.isWatchScreen), @(self.isWatchAutomatic)];
            }
            if ([db hadError]) {
                NSLog(@"Error %d: %@", [db lastErrorCode], [db lastErrorMessage]);
                [self createProfileTable];
            }
        } else {
            NSLog(@"Error owl open db fail %d: %@", [db lastErrorCode], [db lastErrorMessage]);
        }
    }
}

- (void)closeDB
{
    if (db) {
        [db close];
        db = nil;
    }
}

// 新增一条version记录
- (void)insertCurrentVersionWithChangeLog:(NSString *)changeLog {
    NSString *insertSQL = [NSString stringWithFormat:@"INSERT INTO %@ (version, change_log) VALUES (?, ?);", OwlVersionTable];
    BOOL success = [db executeUpdate:insertSQL, @(kDatabaseVersion), changeLog];
    if (success) {
        NSLog(@"insertCurrentVersion success. version: %ld, changeLog: %@", kDatabaseVersion, changeLog);
    } else {
        NSLog(@"insertCurrentVersion fail: %@", [db lastErrorMessage]);
    }
}

- (NSInteger)fetchLatestVersion {
    NSInteger latestVersion = -1; // 初始化为-1，表示未找到版本
    FMResultSet *results = [db executeQuery:[NSString stringWithFormat:@"SELECT version FROM %@ ORDER BY id DESC LIMIT 1", OwlVersionTable]];
    if ([results next]) {
        latestVersion = [results intForColumn:@"version"];
        NSLog(@"Latest version: %ld", latestVersion);
    } else {
        NSLog(@"No version info found or table is empty.");
    }
    
    [results close]; // 关闭结果集
    return latestVersion; // 返回最新版本号
}

// 升级表，兼容旧数据
- (void)updatetable {
    NSInteger currentVersion = [self fetchLatestVersion];
    BOOL result = NO;
    switch (currentVersion) {
        case -1:
            result = [self updateToVersion_1];
            break;
        case 1:
        {
            result = [self updateToVerson_2];
            if (result) {
                [self insertCurrentVersionWithChangeLog:@"1.开关新增'屏幕'字段 ；2.白名单新增'截屏&录屏'字段"];
            }
        }
            break;
        case 2:
        {
            result = [self updateToVerson_3];
            if (result) {
                [self insertCurrentVersionWithChangeLog:@"1.开关新增'自动操作'字段 ；2.白名单新增'自动操作'字段"];
            }
        }
        default:
            break;
    }
    if (!result) return;
    // 递归升级数据库
    [self updatetable];
}

- (BOOL)updateToVersion_1 {
    [self createVersionTable];
    
    NSString *changeLog = @"白名单(app_white)新增'扬声器'字段";
    if (![self isTableExists:OwlAppWhiteTable]) {
        [self insertCurrentVersionWithChangeLog:changeLog];
        [self createWhiteAppTable];
        return YES;
    }
    
    if ([self isTableExists:kTableBackUp(OwlAppWhiteTable)]) {
        // 备份存在
        [self deleteTable:OwlAppWhiteTable];
        [self backupTable:kTableBackUp(OwlAppWhiteTable) to:OwlAppWhiteTable];
    } else {
        // 备份
        if (![self backupTable:OwlAppWhiteTable to:kTableBackUp(OwlAppWhiteTable)]) {
            // 备份失败，待下次启动再次备份
            return NO;
        }
    }
    
    // 插入新的字段
    BOOL success = [self addColumnAndSetDefaultValue:OwlAppWhiteTable newColumn:OwlWatchSpeaker dataType:@"integer NOT NULL" fixedValue:@(NO)];
    // 线上升级逻辑的替代补丁(原线上逻辑无版本号概念，无法判断新旧版本)
    [self addColumnAndSetDefaultValue:OwlAppWhiteTable newColumn:OwlWatchAudio dataType:@"integer NOT NULL" fixedValue:@(YES)];
    [self addColumnAndSetDefaultValue:OwlAppWhiteTable newColumn:OwlWatchCamera dataType:@"integer NOT NULL" fixedValue:@(YES)];
    if (success) {
        [self insertCurrentVersionWithChangeLog:changeLog];
        [self deleteTable:kTableBackUp(OwlAppWhiteTable)];
    } else {
        // 插入失败，还原
        [self deleteTable:OwlAppWhiteTable];
        [self restoreTable:OwlAppWhiteTable fromBackup:kTableBackUp(OwlAppWhiteTable)];
    }
    return success;
}

- (BOOL)updateToVerson_2 {
    BOOL result_Profile = [self updateProcProfileTable_2];
    BOOL result_White = [self updateAppWhiteTable_2];
    return result_Profile && result_White;
}

- (BOOL)updateProcProfileTable_2 {
    return [self upgradeDatabaseTable:OwlProcProfileTable tableNotExists:^{
        [self createProfileTable];
    } newColumn:OwlWatchScreen dataType:@"integer DEFAULT 0" fixedValue:@(0)];
}

- (BOOL)updateAppWhiteTable_2 {
    
    return [self upgradeDatabaseTable:OwlAppWhiteTable tableNotExists:^{
        [self createWhiteAppTable];
    } newColumn:OwlWatchScreen dataType:@"integer NOT NULL" fixedValue:@(0)];
}

- (BOOL)updateToVerson_3 {
    BOOL result_Profile = [self updateProcProfileTable_3];
    BOOL result_White = [self updateAppWhiteTable_3];
    return result_Profile && result_White;
}

- (BOOL)updateProcProfileTable_3 {
    return [self upgradeDatabaseTable:OwlProcProfileTable tableNotExists:^{
        [self createProfileTable];
    } newColumn:OwlWatchAutomatic dataType:@"integer DEFAULT 0" fixedValue:@(0)];
}

- (BOOL)updateAppWhiteTable_3 {
    
    return [self upgradeDatabaseTable:OwlAppWhiteTable tableNotExists:^{
        [self createWhiteAppTable];
    } newColumn:OwlWatchAutomatic dataType:@"integer NOT NULL" fixedValue:@(0)];
}

// 新增一个字段的固定写法
- (BOOL)upgradeDatabaseTable:(NSString *)tableName tableNotExists:(void(^)(void))tableNotExists newColumn:(NSString *)newColumnName dataType:(NSString *)dataType fixedValue:(id)fixedValue {
    if (![self isTableExists:tableName]) {
        if (tableNotExists) tableNotExists();
        return YES;
    }
    
    // 查询表结构，检查字段是否存在
    BOOL columnExists = [self doesTable:tableName containField:newColumnName];
    if (columnExists) return YES;
    
    if ([self isTableExists:kTableBackUp(tableName)]) {
        // 备份存在
        [self deleteTable:tableName];
        [self backupTable:kTableBackUp(tableName) to:tableName];
    } else {
        // 备份
        if (![self backupTable:tableName to:kTableBackUp(tableName)]) {
            // 备份失败，待下次启动再次备份
            return NO;
        }
    }
    
    // 插入新的字段
    BOOL success = [self addColumnAndSetDefaultValue:tableName newColumn:newColumnName dataType:dataType fixedValue:fixedValue];
    if (success) {
        [self deleteTable:kTableBackUp(tableName)];
    } else {
        // 插入失败，还原
        [self deleteTable:tableName];
        [self restoreTable:tableName fromBackup:kTableBackUp(tableName)];
    }
    return success;
}

// 查询并补全非空字段
- (BOOL)fillNullValuesInMandatoryField:(NSString *)tableName mandatoryField:(NSString *)mandatoryField defaultValue:(id)defaultValue {
    // 查询非空字段为空的记录
    NSString *selectSQL = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ IS NULL;", tableName, mandatoryField];
    FMResultSet *results = [db executeQuery:selectSQL];
    
    // 检查是否有记录
    if ([results next]) {
        NSLog(@"Found records with NULL in '%@'.", mandatoryField);
        
        // 更新这些记录并赋予固定值
        NSString *updateSQL = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@' WHERE %@ IS NULL;", tableName, mandatoryField, defaultValue, mandatoryField];
        BOOL success = [db executeUpdate:updateSQL];
        
        if (success) {
            NSLog(@"Successfully updated NULL values in '%@' to '%@'.", mandatoryField, defaultValue);
        } else {
            NSLog(@"Update failed: %@", [db lastErrorMessage]);
        }
        
        return success;
    } else {
        NSLog(@"No records found with NULL in '%@'.", mandatoryField);
    }
    
    return NO;
}

- (BOOL)addColumnAndSetDefaultValue:(NSString *)tableName newColumn:(NSString *)newColumnName dataType:(NSString *)dataType fixedValue:(id)fixedValue {
    // 查询表结构，检查字段是否存在
    BOOL columnExists = [self doesTable:tableName containField:newColumnName];
    
    // 如果字段不存在，则添加字段
    if (!columnExists) {
        // 添加新字段
        NSString *alterSQL = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@ DEFAULT %@;", tableName, newColumnName, dataType, fixedValue];
        BOOL success = [db executeUpdate:alterSQL];
        
        if (success) {
            NSLog(@"Successfully added column '%@' to table '%@'.", newColumnName, tableName);
        } else {
            NSLog(@"Alter table failed: %@", [db lastErrorMessage]);
        }
        return success;
    } else {
        NSLog(@"Column '%@' already exists in table '%@'.", newColumnName, tableName);
    }
    
    return NO;
}

- (BOOL)doesTable:(NSString *)tableName containField:(NSString *)fieldName {
    // 查询表结构，检查字段是否存在
    NSString *checkSQL = [NSString stringWithFormat:@"PRAGMA table_info(%@);", tableName];
    FMResultSet *results = [db executeQuery:checkSQL];
    
    BOOL columnExists = NO;
    while ([results next]) {
        NSString *columnName = [results stringForColumn:@"name"];
        if ([columnName isEqualToString:fieldName]) {
            columnExists = YES;
            break;
        }
    }
    return columnExists;
}

- (BOOL)backupTable:(NSString *)tableName to:(NSString *)backupTable{
    NSString *backupSQL = [NSString stringWithFormat:@"CREATE TABLE %@ AS SELECT * FROM %@;", backupTable, tableName];
    BOOL success = [db executeUpdate:backupSQL];
    
    if (success) {
        NSLog(@"Successfully backed up table: %@", tableName);
    } else {
        NSLog(@"Backup failed: %@", [db lastErrorMessage]);
    }
    return success;
}

// 将备份表还原为原表
- (BOOL)restoreTable:(NSString *)tableName fromBackup:(NSString *)backup {
    NSString *backupSQL = [NSString stringWithFormat:@"RENAME TABLE %@ TO %@;", backup, tableName];
    BOOL success = [db executeUpdate:backupSQL];
    if (success) {
        NSLog(@"Successfully restoreTable: %@, %@", tableName, backup);
    } else {
        NSLog(@"failed restoreTable: %@, %@, error: %@", tableName, backup, [db lastErrorMessage]);
    }
    return success;
}

// 某个表是否存在
- (BOOL)isTableExists:(NSString *)tableName {
    // 参数化查询，避免 SQL 注入
    FMResultSet *rs = [db executeQuery:@"SELECT EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?);", tableName];
    if ([rs next]) {
        // 读取结果：1（存在）或 0（不存在）
        BOOL exists = [rs intForColumnIndex:0];
        [rs close];
        return exists;
    }
    [rs close];
    return NO;
}

// 删除某个表
- (BOOL)deleteTable:(NSString *)tableName {
    NSString *dropSQL = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@;", tableName];
    BOOL success = [db executeUpdate:dropSQL];
    
    if (success) {
        NSLog(@"Successfully deleted table: %@", tableName);
    } else {
        NSLog(@"Deletion failed: %@", [db lastErrorMessage]);
    }
    
    return success;
}

- (void)addLogItemWithUuid:(NSString *)uuid
                   appName:(NSString *)appName
                   appPath:(NSString *)appPath
                 appAction:(Owl2LogThirdAppAction)appAction
                userAction:(Owl2LogUserAction)userAction
                  hardware:(Owl2LogHardware)hardware {
    NSLog(@"addLogItemWithUuid:%@appName:%@appPath:%@appAction:%@userAction:%@hardware:%@", uuid, appName, appPath, @(appAction), @(userAction), @(hardware));
    
    NSDate * currentDate = [NSDate date];
    NSDateFormatter * df = [[NSDateFormatter alloc] init ];
    [df setDateFormat:@"yyyy.MM.dd  HH:mm:ss"];
    NSString *time = [df stringFromDate:currentDate];
    
    NSString *appIconPath = [self iconLocalPathWithAppPath:appPath];
    
    NSMutableDictionary *appDic = [[NSMutableDictionary alloc] initWithCapacity:7];
    if (uuid)        [appDic setObject:uuid forKey:OwlUUID];
    if (time)        [appDic setObject:time forKey:OwlTime];
    if (appName)     [appDic setObject:appName forKey:OwlAppName];
    if (appIconPath) [appDic setObject:appIconPath forKey:OwlAppIconPath];
    if (appAction)   [appDic setObject:@(appAction) forKey:OwlAppAction];
    if (userAction)  [appDic setObject:@(userAction) forKey:OwlUserAction];
    if (hardware)    [appDic setObject:@(hardware) forKey:OwlHardware];
    
    if (uuid && time && appName && appIconPath) {
        [self.logArray insertObject:appDic atIndex:0];
    }
    
    BOOL success = [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (%@,%@,%@,%@,%@,%@,%@) VALUES  (?,?,?,?,?,?,?);", OwlProcLogTableNew, OwlUUID, OwlTime, OwlAppName, OwlAppIconPath, OwlAppAction, OwlUserAction, OwlHardware], uuid, time, appName, appIconPath, @(appAction), @(userAction), @(hardware)];
    if (!success) {
        NSLog(@"addLogItemWithUuid: %@", [db lastErrorMessage]);
    } else {
        NSLog(@"addLogItemWithUuid successfully!");
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:OwlLogChangeNotication object:nil];
    });
}

- (void)updateLogItemWithUuid:(NSString *)uuid
                      appName:(NSString *)appName
                      appPath:(NSString *)appPath
                    appAction:(Owl2LogThirdAppAction)appAction
                   userAction:(Owl2LogUserAction)userAction
                     hardware:(Owl2LogHardware)hardware {
    NSLog(@"updateLogItemWithUuid:%@appName:%@appPath:%@appAction:%@userAction:%@hardware:%@", uuid, appName, appPath, @(appAction), @(userAction), @(hardware));
    
    NSString *appIconPath = [self iconLocalPathWithAppPath:appPath];
    
    NSMutableDictionary *appDic = [[NSMutableDictionary alloc] initWithCapacity:7];
    if (uuid)        [appDic setObject:uuid forKey:OwlUUID];
    // 缺时间
    if (appName)     [appDic setObject:appName forKey:OwlAppName];
    if (appIconPath) [appDic setObject:appIconPath forKey:OwlAppIconPath];
    if (appAction)   [appDic setObject:@(appAction) forKey:OwlAppAction];
    if (userAction)  [appDic setObject:@(userAction) forKey:OwlUserAction];
    if (hardware)    [appDic setObject:@(hardware) forKey:OwlHardware];
    if (uuid) {
        BOOL find = NO;
        NSArray *logArray = self.logArray.copy;
        for (NSMutableDictionary *oldDic in logArray) {
            NSString *oldUUID = [oldDic objectForKey:OwlUUID];
            if ([oldUUID isEqualToString:uuid]) {
                // 插入时间到新的appDic中
                NSString *oldTime = [oldDic objectForKey:OwlTime];
                if (oldTime) [appDic setObject:oldTime forKey:OwlTime];
                // 修改旧的oldDic数据 防止多线程修改self.logArray导致问题，减少排序
                if (uuid)        [oldDic setObject:uuid forKey:OwlUUID];
                if (appName)     [oldDic setObject:appName forKey:OwlAppName];
                if (appIconPath) [oldDic setObject:appIconPath forKey:OwlAppIconPath];
                if (appAction)   [oldDic setObject:@(appAction) forKey:OwlAppAction];
                if (userAction)  [oldDic setObject:@(userAction) forKey:OwlUserAction];
                if (hardware)    [oldDic setObject:@(hardware) forKey:OwlHardware];
                find = YES;
                break;
            }
        }
        
        if (find) {
            // 替换掉旧的
            BOOL success = [db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET %@ = ?, %@ = ?, %@ = ?, %@ = ?, %@ = ? WHERE %@ = ? AND %@ = ?;", OwlProcLogTableNew, OwlAppName, OwlAppIconPath, OwlAppAction, OwlUserAction, OwlHardware, OwlUUID, OwlUserAction], appName, appIconPath, @(appAction), @(userAction), @(hardware), uuid, @(Owl2LogUserActionNone)];
            if (!success) {
                NSLog(@"updateLogItemWithUuid: %@", [db lastErrorMessage]);
            } else {
                NSLog(@"updateLogItemWithUuid successfully!");
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:OwlLogChangeNotication object:nil];
            });
        }
    }
}

- (void)updateAllWatch {
    NSString *strSQL = [NSString stringWithFormat:@"REPLACE INTO %@ (%@,%@,%@,%@,%@) VALUES  (?,?,?,?,?);", OwlProcProfileTable, @"id", OwlWatchCamera, OwlWatchAudio, OwlWatchScreen, OwlWatchAutomatic];
    [db executeUpdate:strSQL, @(1), @(self.isWatchVideo), @(self.isWatchAudio), @(self.isWatchScreen), @(self.isWatchAutomatic)];
}

- (void)addAppWhiteItemToDB:(NSDictionary*)dic
{
    NSString *strSQL = [NSString stringWithFormat:@"REPLACE INTO %@ (%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@) VALUES  (?,?,?,?,?,?,?,?,?,?,?);", OwlAppWhiteTable, OwlAppName, OwlExecutableName, OwlBubblePath, OwlIdentifier, OwlAppIcon, OwlAppleApp, OwlWatchCamera, OwlWatchAudio, OwlWatchSpeaker, OwlWatchScreen, OwlWatchAutomatic];
    NSString *appName= dic[OwlAppName]?:@"";
    NSString *executableName= dic[OwlExecutableName]?:@"";
    NSString *bubblePath= dic[OwlBubblePath]?:@"";
    NSString *identifier= dic[OwlIdentifier]?:@"";
    NSString *appIcon= dic[OwlAppIcon]?:@"";
    NSNumber *appleApp= dic[OwlAppleApp]?:@NO;
    NSNumber *watchCam= dic[OwlWatchCamera]?:@NO;
    NSNumber *watchMic= dic[OwlWatchAudio]?:@NO;
    NSNumber *watchSpeaker= dic[OwlWatchSpeaker]?:@NO;
    NSNumber *watchScreen= dic[OwlWatchScreen]?:@NO;
    NSNumber *watchAutomatic= dic[OwlWatchAutomatic]?:@NO;
    
    BOOL success = [db executeUpdate:strSQL,appName,executableName,bubblePath,identifier,appIcon,appleApp,watchCam,watchMic,watchSpeaker, watchScreen, watchAutomatic];
    if (!success) {
        NSLog(@"addAppWhiteItemToDB: %@", [db lastErrorMessage]);
    } else {
        NSLog(@"addAppWhiteItemToDB successfully!");
    }
}

- (void)removeAppWhiteItemToDB:(NSDictionary*)dic
{
    [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?", OwlAppWhiteTable, OwlIdentifier], [dic objectForKey:OwlIdentifier]];
}

- (NSArray *)getWhiteList {
    NSMutableArray *resultsArray = [NSMutableArray array];
    // 构建查询语句
    NSString *selectSQL = [NSString stringWithFormat:@"SELECT * FROM %@ ORDER BY %@ ASC", OwlAppWhiteTable, OwlAppName];
    FMResultSet *results = [db executeQuery:selectSQL];
    while ([results next]) {
        // 创建一个字典来存储每一行的数据
        NSMutableDictionary *rowDictionary = [NSMutableDictionary dictionary];
        
        // 获取每一列的数据
        NSString *appName = [results stringForColumn:OwlAppName];
        NSString *executableName = [results stringForColumn:OwlExecutableName];
        NSString *bubblePath = [results stringForColumn:OwlBubblePath];
        NSString *identifier = [results stringForColumn:OwlIdentifier];
        NSString *appIcon = [results stringForColumn:OwlAppIcon];
        NSString *appleApp = [results stringForColumn:OwlAppleApp];
        NSInteger watchCamera = [results intForColumn:OwlWatchCamera];
        NSInteger watchAudio = [results intForColumn:OwlWatchAudio];
        NSInteger watchSpeaker = [results intForColumn:OwlWatchSpeaker];
        NSInteger watchScreen = [results intForColumn:OwlWatchScreen];
        NSInteger watchAutomatic = [results intForColumn:OwlWatchAutomatic];
        
        // 将数据添加到字典中
        if (appName) [rowDictionary setObject:appName forKey:OwlAppName];
        if (executableName) [rowDictionary setObject:executableName forKey:OwlExecutableName];
        if (bubblePath) [rowDictionary setObject:bubblePath forKey:OwlBubblePath];
        if (identifier) [rowDictionary setObject:identifier forKey:OwlIdentifier];
        if (appIcon) [rowDictionary setObject:appIcon forKey:OwlAppIcon];
        if (appleApp) [rowDictionary setObject:appleApp forKey:OwlAppleApp];
        [rowDictionary setObject:@(watchCamera) forKey:OwlWatchCamera];
        [rowDictionary setObject:@(watchAudio) forKey:OwlWatchAudio];
        [rowDictionary setObject:@(watchSpeaker) forKey:OwlWatchSpeaker];
        [rowDictionary setObject:@(watchScreen) forKey:OwlWatchScreen];
        [rowDictionary setObject:@(watchAutomatic) forKey:OwlWatchAutomatic];
        
        // 将字典添加到数组中
        [resultsArray addObject:rowDictionary];
    }
    [results close];
    return [resultsArray copy]; // 返回不可变数组
}

@end
