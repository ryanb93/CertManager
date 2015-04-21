//
//  FSHandler.m
//  CertManager
//
//  Created by Ryan Burke on 17/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import "FSHandler.h"

@implementation FSHandler

static NSString * const PREFERENCES = @"/private/var/mobile/Library/Preferences";

/**
 *  Writes an array to the plist.
 *
 *  @param fileName The name of the plist to write to.
 *  @param data     The data to write to the file.
 */
+ (void) writeToPlist: (NSString*)fileName withData:(id) data
{
    NSLog(@"write to plist %@", data);
    if([data respondsToSelector:@selector(writeToFile:atomically:)]) {
        NSLog(@"Responds to selector");
        NSLog(@"Writing %@ to %@", data, fileName);
        
   		BOOL success = [data writeToFile:[NSString stringWithFormat:@"%@/%@.plist", PREFERENCES, fileName] atomically:YES];
    	if(success) {
            NSLog(@"SUCCESS");
    		//Send a notification to the system that we have changed values.
    		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("uk.ac.surrey.rb00166.CertManager/reload"), NULL, NULL, YES);
    	}
        else {
            NSLog(@"FAIL WALE");
        }
    }
}

/**
 *  Reads an array from a plist.
 *
 *  @param fileName The name of the plist to read from.
 *
 *  @return The values of the plist in an array.
 */
+ (NSMutableArray *) readArrayFromPlist: (NSString *)fileName {
    NSArray *arr = [[NSArray alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.plist", PREFERENCES, fileName]];
    return [[NSMutableArray alloc] initWithArray:arr];
}

/**
 *  Reads an dictionary from a plist.
 *
 *  @param fileName The name of the plist to read from.
 *
 *  @return The values of the plist in an dictionary.
 */
+ (NSMutableDictionary *) readDictionaryFromPlist: (NSString *)fileName {
    NSDictionary *arr = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.plist", PREFERENCES, fileName]];
    return [[NSMutableDictionary alloc] initWithDictionary:arr];
}

@end
