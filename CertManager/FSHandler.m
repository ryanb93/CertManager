//
//  FSHandler.m
//  CertManager
//
//  Created by Ryan Burke on 17/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "FSHandler.h"

@implementation FSHandler

+ (void) writeToPlist: (NSString*)fileName withData:(NSMutableArray *)data
{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"];
    [data writeToFile:filePath atomically: YES];
}

+ (NSMutableArray *) readFromPlist: (NSString *)fileName {
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"];
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    
    if (fileExists) {
        NSMutableArray *arr = [[NSMutableArray alloc] initWithContentsOfFile:filePath];
        return arr;
    } else {
        return nil;
    }
}

@end
