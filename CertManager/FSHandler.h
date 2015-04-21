//
//  FSHandler.h
//  CertManager
//
//  Created by Ryan Burke on 17/02/2015.
//  Copyright (c) 2015 Ryan Burke. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FSHandler : NSObject

+ (void)writeToPlist: (NSString*)fileName withData:(id)data;
+ (NSMutableArray *)readArrayFromPlist: (NSString *)fileName;
+ (NSMutableDictionary *)readDictionaryFromPlist: (NSString *)fileName;

@end
