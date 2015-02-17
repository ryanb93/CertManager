//
//  FSHandler.m
//  CertManager
//
//  Created by Ryan Burke on 17/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "FSHandler.h"

@implementation FSHandler

+ (NSString *) getFilePathForFileName:(NSString *)fileName {
    
    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    filePath = [filePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", fileName]];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        NSString *sourcePath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"];
        [fileManager copyItemAtPath:sourcePath toPath:filePath error:nil];
    }
    
    return filePath;
}


+ (void) writeToPlist: (NSString*)fileName withData:(NSMutableArray *)data
{
    NSString *filePath = [self getFilePathForFileName:fileName];
    [data writeToFile:filePath atomically: YES];
}

+ (NSMutableArray *) readFromPlist: (NSString *)fileName {
    NSString *filePath = [self getFilePathForFileName:fileName];
    NSArray *arr = [[NSMutableArray alloc] initWithContentsOfFile:filePath];
    return [NSMutableArray arrayWithArray:arr];
}

@end
