//
//  FSHandler.m
//  CertManager
//
//  Created by Ryan Burke on 17/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "FSHandler.h"

@implementation FSHandler

/**
 *  Returns the path of a plist from within the documents directory.
 *  If the file does not exist already then it will create it.
 *
 *  @param fileName The name of the plist.
 *
 *  @return The full path of the plist.
 */
+ (NSString *) getFilePathForFileName:(NSString *)fileName {
    
    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    filePath = [filePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", fileName]];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        NSString *sourcePath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"];
        [fileManager copyItemAtPath:sourcePath toPath:filePath error:nil];
    }
    
    return filePath;
}

/**
 *  Writes an array to the plist.
 *
 *  @param fileName The name of the plist to write to.
 *  @param data     The data to write to the file.
 */
+ (void) writeToPlist: (NSString*)fileName withData:(NSMutableArray *)data
{
    NSString *filePath = [self getFilePathForFileName:fileName];
    [data writeToFile:filePath atomically: YES];
}

/**
 *  Reads an array from a plist.
 *
 *  @param fileName The name of the plist to read from.
 *
 *  @return The values of the plist in an array.
 */
+ (NSMutableArray *) readFromPlist: (NSString *)fileName {
    NSString *filePath = [self getFilePathForFileName:fileName];
    NSArray *arr = [[NSArray alloc] initWithContentsOfFile:filePath];
    return [[NSMutableArray alloc] initWithArray:arr];
}

@end
