//
//  FSHandler.m
//  CertManager
//
//  Created by Ryan Burke on 17/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "FSHandler.h"

#define PREFERENCES @"/private/var/mobile/Library/Preferences"

@implementation FSHandler


/**
 *  Writes an array to the plist.
 *
 *  @param fileName The name of the plist to write to.
 *  @param data     The data to write to the file.
 */
+ (void) writeToPlist: (NSString*)fileName withData:(NSMutableArray *)data
{
    [data writeToFile:[NSString stringWithFormat:@"%@/%@.plist", PREFERENCES, fileName] atomically: YES];
}

/**
 *  Reads an array from a plist.
 *
 *  @param fileName The name of the plist to read from.
 *
 *  @return The values of the plist in an array.
 */
+ (NSMutableArray *) readFromPlist: (NSString *)fileName {
    NSArray *arr = [[NSArray alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.plist", PREFERENCES, fileName]];
    return [[NSMutableArray alloc] initWithArray:arr];
}

@end
